import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { StoreService } from 'src/app/services/store.service';

export interface TransactionHistory {
  id: string;
  firestoreId: string;
  type: 'debt' | 'payment';
  storeName: string;
  storeProfileImage?: string;
  storeColor: string;
  storeInitials: string;
  storeAddress: string;
  storeContact: string;
  totalAmount: number;
  paymentAmount?: number; // For payment transactions
  transactionDate: any;
  status: string;
  paymentStatus?: string;
  items: any[];
  customerName: string;
  customerPhone: string;
  receipt_image?: string;
  paymentMethod: string;
  // For debt payments
  originalDebtId?: string;
  remainingBalance?: number;
  paid_by?: string;
  notes?: string;
  // Additional fields for receipt viewing
  dueDate?: any;
  initialPayment?: number;
  payments?: any[];
  employee_id?: string;
}

@Component({
  selector: 'app-customer-tab3',
  templateUrl: './tab3.page.html',
  styleUrls: ['./tab3.page.scss'],
  standalone: false,
})
export class Tab3Page implements OnInit {
  transactionHistory: TransactionHistory[] = [];
  filteredTransactions: TransactionHistory[] = [];
  
  // Search and filter
  searchTerm: string = '';
  transactionType: string = 'all';
  dateRange: string = 'all';
  sortBy: string = 'newest';
  
  // Date filters
  customStartDate: string = '';
  customEndDate: string = '';
  
  // Summary statistics
  totalDebts: number = 0;
  totalPayments: number = 0;
  totalTransactions: number = 0;
  storesVisited: number = 0;
  
  // Loading states
  isLoading: boolean = false;
  searchTimeout: any;

  // Receipt viewing
  selectedTransaction: TransactionHistory | null = null;
  showReceiptModal: boolean = false;

  downloadSuccess: boolean = false;

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private storeService: StoreService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private modalController: ModalController,
    private alertController: AlertController
  ) { }

  async ngOnInit() {
    await this.loadTransactionHistory();
  }

  async loadTransactionHistory() {
    const loading = await this.loadingController.create({
      message: 'Loading your debt history...'
    });
    await loading.present();

    try {
      this.isLoading = true;
      this.transactionHistory = []; // Clear existing data
      await Promise.all([
        this.loadDebtTransactions(),
        this.loadPaymentTransactions()
      ]);
      
      this.sortTransactions();
      this.calculateSummary();
      this.applyFilters();
      
    } catch (error) {
      console.error('Error loading transaction history:', error);
      this.showToast('Error loading your debt history', 'danger');
    } finally {
      this.isLoading = false;
      await loading.dismiss();
    }
  }

  async loadDebtTransactions() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      if (!customerName) {
        throw new Error('User not authenticated');
      }

      const debtProductsRef = collection(this.firestore, 'debt_products');
      const q = query(
        debtProductsRef,
        where('customerName', '==', customerName)
      );
      
      const querySnapshot = await getDocs(q);
      
      for (const doc of querySnapshot.docs) {
        const data = doc.data();
        const storeInfo = await this.getStoreInfo(data['store_owner_id']);
        
        const transaction: TransactionHistory = {
          id: data['id'] || doc.id,
          firestoreId: doc.id,
          type: 'debt',
          storeName: storeInfo.storeName,
          storeProfileImage: storeInfo.storeProfileImage,
          storeColor: storeInfo.storeColor,
          storeInitials: storeInfo.storeInitials,
          storeAddress: storeInfo.storeAddress,
          storeContact: storeInfo.storeContact,
          totalAmount: data['total'] || 0,
          transactionDate: data['created_at'] || null,
          status: data['status'] || 'pending',
          paymentStatus: data['payment_status'] || 'unpaid',
          items: data['items'] || [],
          customerName: data['customerName'] || '',
          customerPhone: data['customerPhone'] || '',
          receipt_image: data['receipt_image'] || '',
          paymentMethod: 'debt',
          remainingBalance: data['remainingBalance'] || data['total'] || 0,
          initialPayment: data['initialPayment'] || 0,
          dueDate: data['dueDate'] || null,
          payments: data['payments'] || [],
          employee_id: data['employee_id'] || ''
        };

        this.transactionHistory.push(transaction);
      }
    } catch (error) {
      console.error('Error loading debt transactions:', error);
    }
  }

// Replace your loadPaymentTransactions method (around line 175)

async loadPaymentTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const customerName = currentUser?.full_name;
    
    if (!customerName) {
      throw new Error('User not authenticated');
    }

    // Load debt products to get payment history
    const debtProductsRef = collection(this.firestore, 'debt_products');
    const q = query(
      debtProductsRef,
      where('customerName', '==', customerName)
    );
    
    const querySnapshot = await getDocs(q);
    
    for (const doc of querySnapshot.docs) {
      const data = doc.data();
      const payments = data['payments'] || [];
      const storeInfo = await this.getStoreInfo(data['store_owner_id']);
      
      // Create transaction entries for each payment
      payments.forEach((payment: any, index: number) => {
        // Generate clean payment ID without timestamp
        const paymentId = `PMT-${data['id']}-${(index + 1).toString().padStart(3, '0')}`;
        
        const transaction: TransactionHistory = {
          id: paymentId, // Clean ID without timestamp
          firestoreId: doc.id,
          type: 'payment',
          storeName: storeInfo.storeName,
          storeProfileImage: storeInfo.storeProfileImage,
          storeColor: storeInfo.storeColor,
          storeInitials: storeInfo.storeInitials,
          storeAddress: storeInfo.storeAddress,
          storeContact: storeInfo.storeContact,
          totalAmount: data['total'] || 0,
          paymentAmount: payment.amount,
          transactionDate: payment.paymentDate,
          status: 'completed',
          items: data['items'] || [],
          customerName: data['customerName'] || '',
          customerPhone: data['customerPhone'] || '',
          paymentMethod: 'cash',
          originalDebtId: data['id'],
          remainingBalance: payment.remainingBalance,
          paid_by: payment.paid_by,
          notes: payment.notes,
          employee_id: data['employee_id'] || ''
        };

        this.transactionHistory.push(transaction);
      });
    }
  } catch (error) {
    console.error('Error loading payment transactions:', error);
  }
}

  private async getStoreInfo(storeOwnerId: string): Promise<any> {
    try {
      if (!storeOwnerId) {
        return this.getDefaultStoreInfo();
      }

      const storeProfile = await this.storeService.getStoreProfile(storeOwnerId);
      const storeOwner = await this.storeService.getStoreOwnerById(storeOwnerId);
      
      const storeName = storeOwner?.store_name || 'Unknown Store';
      const storeColor = this.getStoreColor(storeName);
      const storeInitials = this.getStoreInitials(storeName);

      return {
        storeName: storeName,
        storeProfileImage: storeProfile?.store_image || null,
        storeColor: storeColor,
        storeInitials: storeInitials,
        storeAddress: this.buildStoreAddress(storeOwner),
        storeContact: storeOwner?.phone_number || 'N/A'
      };
    } catch (error) {
      console.error('Error getting store info:', error);
      return this.getDefaultStoreInfo();
    }
  }

  private getDefaultStoreInfo() {
    return {
      storeName: 'Unknown Store',
      storeProfileImage: null,
      storeColor: '#666666',
      storeInitials: '??',
      storeAddress: 'Address not available',
      storeContact: 'N/A'
    };
  }

  private buildStoreAddress(storeOwner: any): string {
    if (!storeOwner) return 'Address not available';
    
    const addressParts = [];
    if (storeOwner.barangay) addressParts.push(storeOwner.barangay);
    if (storeOwner.municipality) addressParts.push(storeOwner.municipality);
    if (storeOwner.province) addressParts.push(storeOwner.province);
    
    return addressParts.join(', ') || 'Address not specified';
  }

  private getStoreColor(storeName: string): string {
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    const colorIndex = storeName.charCodeAt(0) % colors.length;
    return colors[colorIndex];
  }

  private getStoreInitials(storeName: string): string {
    if (!storeName) return '??';
    
    const words = storeName.trim().split(' ');
    if (words.length === 1) {
      return words[0].substring(0, 2).toUpperCase();
    } else {
      const firstInitial = words[0].charAt(0).toUpperCase();
      const lastInitial = words[words.length - 1].charAt(0).toUpperCase();
      return firstInitial + lastInitial;
    }
  }

  // Filtering and Sorting
  applyFilters() {
    let filtered = this.transactionHistory;

    // Filter by transaction type
    if (this.transactionType !== 'all') {
      filtered = filtered.filter(transaction => transaction.type === this.transactionType);
    }

    // Filter by date range
    if (this.dateRange !== 'all') {
      filtered = this.filterByDateRange(filtered, this.dateRange);
    }

    // Filter by custom date range
    if (this.customStartDate && this.customEndDate) {
      filtered = this.filterByCustomDateRange(filtered);
    }

    // Search filter
    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(transaction =>
        transaction.storeName.toLowerCase().includes(term) ||
        transaction.id.toLowerCase().includes(term) ||
        this.formatCurrency(transaction.totalAmount).toLowerCase().includes(term)
      );
    }

    // Sort
    this.filteredTransactions = this.sortTransactionsList(filtered);
  }

  private filterByDateRange(transactions: TransactionHistory[], range: string): TransactionHistory[] {
    const now = new Date();
    let startDate = new Date();

    switch (range) {
      case 'today':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'week':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'month':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'year':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
      default:
        return transactions;
    }

    return transactions.filter(transaction => {
      const transactionDate = transaction.transactionDate?.toDate ? 
        transaction.transactionDate.toDate() : new Date(transaction.transactionDate);
      return transactionDate >= startDate;
    });
  }

  private filterByCustomDateRange(transactions: TransactionHistory[]): TransactionHistory[] {
    const startDate = new Date(this.customStartDate);
    const endDate = new Date(this.customEndDate);
    endDate.setHours(23, 59, 59, 999);

    return transactions.filter(transaction => {
      const transactionDate = transaction.transactionDate?.toDate ? 
        transaction.transactionDate.toDate() : new Date(transaction.transactionDate);
      return transactionDate >= startDate && transactionDate <= endDate;
    });
  }

  private sortTransactions() {
    this.transactionHistory.sort((a, b) => {
      const dateA = a.transactionDate?.toDate ? a.transactionDate.toDate() : new Date(a.transactionDate);
      const dateB = b.transactionDate?.toDate ? b.transactionDate.toDate() : new Date(b.transactionDate);
      return dateB.getTime() - dateA.getTime(); // Newest first by default
    });
  }

  private sortTransactionsList(transactions: TransactionHistory[]): TransactionHistory[] {
    return [...transactions].sort((a, b) => {
      const dateA = a.transactionDate?.toDate ? a.transactionDate.toDate() : new Date(a.transactionDate);
      const dateB = b.transactionDate?.toDate ? b.transactionDate.toDate() : new Date(b.transactionDate);

      switch (this.sortBy) {
        case 'newest':
          return dateB.getTime() - dateA.getTime();
        case 'oldest':
          return dateA.getTime() - dateB.getTime();
        case 'amount_high':
          return (b.paymentAmount || b.totalAmount) - (a.paymentAmount || a.totalAmount);
        case 'amount_low':
          return (a.paymentAmount || a.totalAmount) - (b.paymentAmount || b.totalAmount);
        default:
          return dateB.getTime() - dateA.getTime();
      }
    });
  }

  // Summary Calculations
  private calculateSummary() {
    this.totalTransactions = this.transactionHistory.length;
    
    const debtTransactions = this.transactionHistory.filter(t => t.type === 'debt');
    const paymentTransactions = this.transactionHistory.filter(t => t.type === 'payment');
    
    this.totalDebts = debtTransactions.length;
    this.totalPayments = paymentTransactions.length;
    
    const uniqueStores = new Set(this.transactionHistory.map(t => t.storeName));
    this.storesVisited = uniqueStores.size;
  }

  // Receipt Viewing Methods
  viewReceipt(transaction: TransactionHistory) {
    this.selectedTransaction = transaction;
    this.showReceiptModal = true;
  }

  closeReceiptModal() {
    this.showReceiptModal = false;
    this.selectedTransaction = null;
  }

async downloadReceipt(transaction: TransactionHistory) {
  const loading = await this.loadingController.create({
    message: 'Generating receipt image...'
  });
  await loading.present();

  try {
    this.downloadSuccess = false;
    // Generate and download as image
    await this.generateReceiptImage(transaction);
    
    // Show success animation
    this.downloadSuccess = true;
    setTimeout(() => {
      this.downloadSuccess = false;
    }, 1000);
    
    this.showToast('Receipt image downloaded successfully', 'success');
  } catch (error) {
    console.error('Error downloading receipt:', error);
    this.showToast('Error downloading receipt', 'danger');
  } finally {
    await loading.dismiss();
  }
}

// Replace your generateReceiptImage method with this FINAL fixed version

private async generateReceiptImage(transaction: TransactionHistory): Promise<void> {
  return new Promise((resolve, reject) => {
    try {
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d')!;
      
      // Set canvas size (thermal receipt size - 80mm width = 576px)
      const canvasWidth = 576;
      const padding = 35;
      const contentWidth = canvasWidth - (padding * 2);
      let yPosition = padding + 10;
      
      // Calculate total height needed
      const estimatedHeight = this.calculateReceiptHeight(transaction);
      canvas.width = canvasWidth;
      canvas.height = estimatedHeight;
      
      // Fill white background
      ctx.fillStyle = '#FFFFFF';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      
      // Reset to black for text
      ctx.fillStyle = '#000000';
      ctx.textAlign = 'center';
      
      // ===== HEADER =====
      ctx.font = 'bold 24px Arial';
      ctx.fillText('OFFICIAL RECEIPT', canvasWidth / 2, yPosition);
      yPosition += 35;

      // Store Name
      ctx.font = 'bold 18px Arial';
      const storeNameLines = this.wrapTextToArray(ctx, transaction.storeName.toUpperCase(), contentWidth);
      storeNameLines.forEach(line => {
        ctx.fillText(line, canvasWidth / 2, yPosition);
        yPosition += 24;
      });
      yPosition += 10;

      // Store Address
      ctx.font = '13px Arial';
      const addressLines = this.wrapTextToArray(ctx, transaction.storeAddress, contentWidth);
      addressLines.forEach(line => {
        ctx.fillText(line, canvasWidth / 2, yPosition);
        yPosition += 18;
      });
      yPosition += 5;

      // Contact
      ctx.fillText(`Contact: ${transaction.storeContact}`, canvasWidth / 2, yPosition);
      yPosition += 28;

      // Separator
      this.drawSeparator(ctx, canvasWidth, padding, yPosition);
      yPosition += 22;

      // ===== TRANSACTION DETAILS =====
      ctx.textAlign = 'left';
      ctx.font = 'bold 15px Arial';
      ctx.fillText('TRANSACTION DETAILS', padding, yPosition);
      yPosition += 26;

      ctx.font = '13px Arial';
      
      // Receipt No - Wrap if too long
      const receiptNoText = `Receipt No: ${transaction.id}`;
      const receiptNoLines = this.wrapTextToArray(ctx, receiptNoText, contentWidth);
      receiptNoLines.forEach(line => {
        ctx.fillText(line, padding, yPosition);
        yPosition += 20;
      });

      ctx.fillText(`Date: ${this.formatDateForReceipt(transaction.transactionDate)}`, padding, yPosition);
      yPosition += 20;

      // Customer name - Wrap if too long
      const customerLines = this.wrapTextToArray(ctx, `Customer: ${transaction.customerName}`, contentWidth);
      customerLines.forEach(line => {
        ctx.fillText(line, padding, yPosition);
        yPosition += 20;
      });

      ctx.fillText(`Phone: ${transaction.customerPhone}`, padding, yPosition);
      yPosition += 28;

      // ===== TRANSACTION TYPE =====
      if (transaction.type === 'debt') {
        ctx.font = 'bold 14px Arial';
        ctx.fillText('DEBT TRANSACTION', padding, yPosition);
        yPosition += 24;

        ctx.font = '13px Arial';
        ctx.fillText(`Total Amount: ${this.formatCurrency(transaction.totalAmount)}`, padding, yPosition);
        yPosition += 20;

        ctx.fillText(`Initial Payment: ${this.formatCurrency(transaction.initialPayment || 0)}`, padding, yPosition);
        yPosition += 20;

        ctx.font = 'bold 13px Arial';
        ctx.fillText(`Remaining Balance: ${this.formatCurrency(transaction.remainingBalance || 0)}`, padding, yPosition);
        yPosition += 20;
        ctx.font = '13px Arial';

        if (transaction.dueDate) {
          ctx.fillText(`Due Date: ${this.formatDateForReceipt(transaction.dueDate)}`, padding, yPosition);
          yPosition += 20;
        }

        ctx.fillText(`Status: ${(transaction.paymentStatus || 'PENDING').toUpperCase()}`, padding, yPosition);
        yPosition += 28;

      } else if (transaction.type === 'payment') {
        ctx.font = 'bold 14px Arial';
        ctx.fillText('PAYMENT RECEIPT', padding, yPosition);
        yPosition += 24;

        ctx.font = 'bold 13px Arial';
        ctx.fillText(`Payment Amount: ${this.formatCurrency(transaction.paymentAmount || 0)}`, padding, yPosition);
        yPosition += 20;
        ctx.font = '13px Arial';

        // Processed By - Wrap if too long
        const processedByLines = this.wrapTextToArray(ctx, `Processed By: ${transaction.paid_by || 'Store Staff'}`, contentWidth);
        processedByLines.forEach(line => {
          ctx.fillText(line, padding, yPosition);
          yPosition += 20;
        });

        ctx.fillText(`Remaining Balance: ${this.formatCurrency(transaction.remainingBalance || 0)}`, padding, yPosition);
        yPosition += 20;

        if (transaction.notes) {
          const notesLines = this.wrapTextToArray(ctx, `Notes: ${transaction.notes}`, contentWidth);
          notesLines.forEach(line => {
            ctx.fillText(line, padding, yPosition);
            yPosition += 18;
          });
        }
        yPosition += 10;
      }

      // Separator
      this.drawSeparator(ctx, canvasWidth, padding, yPosition);
      yPosition += 22;

      // ===== ITEMS SECTION =====
      if (transaction.items && transaction.items.length > 0) {
        ctx.font = 'bold 15px Arial';
        ctx.fillText('ITEMS PURCHASED', padding, yPosition);
        yPosition += 26;

        // Table header with better positioning
        ctx.font = 'bold 12px Arial';
        ctx.fillText('ITEM', padding, yPosition);
        ctx.fillText('QTY', canvasWidth - 240, yPosition);
        ctx.fillText('PRICE', canvasWidth - 160, yPosition);
        ctx.textAlign = 'right';
        ctx.fillText('TOTAL', canvasWidth - padding, yPosition);
        ctx.textAlign = 'left';
        yPosition += 6;

        this.drawSeparator(ctx, canvasWidth, padding, yPosition);
        yPosition += 16;

        // Items
        ctx.font = '12px Arial';
        for (const item of transaction.items) {
          const itemName = item.product_name || item.name || 'Unknown Item';
          const quantity = item.quantity || 0;
          const price = item.price || item.sellingPrice || 0;
          const total = quantity * price;

          // Item name - MORE SPACE for wrapping
          const maxItemNameWidth = contentWidth - 260; // Give more space from right columns
          const nameLines = this.wrapTextToArray(ctx, itemName, maxItemNameWidth);
          
          nameLines.forEach((line, index) => {
            ctx.fillText(line, padding, yPosition + (index * 18));
          });

          // Quantity, Price, Total - BETTER SPACING
          ctx.fillText(`${quantity}`, canvasWidth - 240, yPosition);
          ctx.fillText(this.formatCurrency(price), canvasWidth - 160, yPosition);
          ctx.textAlign = 'right';
          ctx.fillText(this.formatCurrency(total), canvasWidth - padding, yPosition);
          ctx.textAlign = 'left';
          
          yPosition += (nameLines.length * 18) + 6;
        }

        yPosition += 8;

        // Total line - FIXED SPACING FOR GRAND TOTAL
        this.drawSeparator(ctx, canvasWidth, padding, yPosition);
        yPosition += 22;

        ctx.font = 'bold 14px Arial';
        // Put GRAND TOTAL on left side and amount on right side - NO OVERLAP
        ctx.fillText('GRAND TOTAL:', padding, yPosition);
        ctx.textAlign = 'right';
        ctx.fillText(this.formatCurrency(transaction.totalAmount), canvasWidth - padding, yPosition);
        ctx.textAlign = 'left';
        yPosition += 30;
      }

      // ===== PAYMENT HISTORY - FIXED "BY" COLUMN =====
      if (transaction.type === 'debt' && transaction.payments && transaction.payments.length > 0) {
        this.drawSeparator(ctx, canvasWidth, padding, yPosition);
        yPosition += 22;

        ctx.font = 'bold 15px Arial';
        ctx.fillText('PAYMENT HISTORY', padding, yPosition);
        yPosition += 26;

        // Table headers - ADJUSTED POSITIONS FOR BETTER SPACING
        ctx.font = 'bold 12px Arial';
        ctx.fillText('DATE', padding, yPosition);
        ctx.fillText('AMOUNT', padding + 120, yPosition); // Move amount to middle
        ctx.fillText('BY', padding + 260, yPosition); // Move BY column with more space
        yPosition += 6;

        this.drawSeparator(ctx, canvasWidth, padding, yPosition);
        yPosition += 16;

        ctx.font = '12px Arial';
        for (const payment of transaction.payments) {
          // Date
          ctx.fillText(this.formatDateShort(payment.paymentDate), padding, yPosition);
          
          // Amount
          ctx.fillText(this.formatCurrency(payment.amount), padding + 120, yPosition);
          
          // BY - Wrap to next line if too long
          const paidByName = payment.paid_by || 'Store';
          const maxByWidth = contentWidth - 280; // Space available for "BY" column
          const byLines = this.wrapTextToArray(ctx, paidByName, maxByWidth);
          
          byLines.forEach((line, index) => {
            ctx.fillText(line, padding + 260, yPosition + (index * 18));
          });
          
          yPosition += (byLines.length * 18) + 4;
        }
        yPosition += 18;
      }

      // ===== FOOTER =====
      this.drawSeparator(ctx, canvasWidth, padding, yPosition);
      yPosition += 26;

      ctx.textAlign = 'center';
      ctx.font = 'bold 15px Arial';
      ctx.fillText('Thank you for your business!', canvasWidth / 2, yPosition);
      yPosition += 26;

      ctx.font = '11px Arial';
      ctx.fillStyle = '#555555';
      ctx.fillText('This is an official computer-generated receipt', canvasWidth / 2, yPosition);
      yPosition += 18;
      ctx.fillText('No signature required', canvasWidth / 2, yPosition);
      yPosition += 18;
      
      const generatedDate = new Date().toLocaleDateString('en-PH', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
      ctx.fillText(`Generated: ${generatedDate}`, canvasWidth / 2, yPosition);
      yPosition += 25;

      // Download
      const dataUrl = canvas.toDataURL('image/png', 1.0);
      this.downloadImageData(dataUrl, `receipt-${transaction.id}.png`);
      
      resolve();
    } catch (error) {
      console.error('Error generating receipt image:', error);
      reject(error);
    }
  });
}

// Updated height calculation
private calculateReceiptHeight(transaction: TransactionHistory): number {
  let height = 550;
  
  // Store info
  height += 120;
  
  // Items with wrapping consideration
  if (transaction.items && transaction.items.length > 0) {
    transaction.items.forEach(item => {
      const itemName = item.product_name || item.name || 'Unknown Item';
      const estimatedLines = Math.ceil(itemName.length / 25); // More conservative estimate
      height += estimatedLines * 20 + 10;
    });
    height += 120;
  }
  
  // Payment history with name wrapping
  if (transaction.type === 'debt' && transaction.payments && transaction.payments.length > 0) {
    transaction.payments.forEach(payment => {
      const paidByName = payment.paid_by || 'Store';
      const estimatedLines = Math.ceil(paidByName.length / 20);
      height += estimatedLines * 20 + 8;
    });
    height += 120;
  }
  
  // Long names and IDs
  height += 80;
  
  return height + 120;
}
private wrapTextToArray(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
  const words = text.split(' ');
  const lines: string[] = [];
  let currentLine = '';

  for (const word of words) {
    const testLine = currentLine + (currentLine ? ' ' : '') + word;
    const metrics = ctx.measureText(testLine);
    
    if (metrics.width > maxWidth && currentLine) {
      lines.push(currentLine);
      currentLine = word;
    } else {
      currentLine = testLine;
    }
  }
  
  if (currentLine) {
    lines.push(currentLine);
  }
  
  return lines.length > 0 ? lines : [text];
}

private drawSeparator(ctx: CanvasRenderingContext2D, canvasWidth: number, padding: number, y: number) {
  ctx.beginPath();
  ctx.moveTo(padding, y);
  ctx.lineTo(canvasWidth - padding, y);
  ctx.strokeStyle = '#000000';
  ctx.lineWidth = 1.5;
  ctx.stroke();
}

private formatDateForReceipt(date: any): string {
  if (!date) return 'N/A';
  
  try {
    const jsDate = date.toDate ? date.toDate() : new Date(date);
    return jsDate.toLocaleDateString('en-PH', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  } catch (error) {
    return 'Invalid Date';
  }
}

private formatDateShort(date: any): string {
  if (!date) return 'N/A';
  
  try {
    const jsDate = date.toDate ? date.toDate() : new Date(date);
    return jsDate.toLocaleDateString('en-PH', {
      month: 'short',
      day: '2-digit'
    });
  } catch (error) {
    return 'Invalid';
  }
}

private downloadImageData(dataUrl: string, filename: string) {
  const link = document.createElement('a');
  link.href = dataUrl;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}


private wrapText(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, maxWidth: number, lineHeight: number): number {
  const words = text.split(' ');
  let line = '';
  let lines = 1;

  for (let n = 0; n < words.length; n++) {
    const testLine = line + words[n] + ' ';
    const metrics = ctx.measureText(testLine);
    const testWidth = metrics.width;
    
    if (testWidth > maxWidth && n > 0) {
      ctx.fillText(line, x, y);
      line = words[n] + ' ';
      y += lineHeight;
      lines++;
    } else {
      line = testLine;
    }
  }
  ctx.fillText(line, x, y);
  return lines;
}

  // Utility Methods
  getTransactionIcon(type: string): string {
    switch (type) {
      case 'debt': return 'card';
      case 'payment': return 'cash';
      default: return 'receipt';
    }
  }

  getTransactionColor(type: string): string {
    switch (type) {
      case 'debt': return 'warning';
      case 'payment': return 'success';
      default: return 'medium';
    }
  }

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

formatDate(date: any): string {
  if (!date) return 'N/A';
  
  try {
    const jsDate = date.toDate ? date.toDate() : new Date(date);
    return jsDate.toLocaleDateString('en-PH', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
      // Removed hour and minute - NO TIMESTAMP!
    });
  } catch (error) {
    return 'Invalid Date';
  }
}

  formatCurrency(amount: number): string {
    return `₱${amount?.toFixed(2) || '0.00'}`;
  }

  // Event Handlers
  onFilterChange() {
    this.applyFilters();
  }

  onSearchChange() {
    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      this.applyFilters();
    }, 300);
  }

  onSortChange() {
    this.applyFilters();
  }

  async doRefresh(event: any) {
    await this.loadTransactionHistory();
    event.target.complete();
  }

  // Image error handler
  handleImageError(event: any) {
    console.log('Image load error:', event);
    event.target.style.display = 'none';
  }

  // TrackBy for performance
  trackByTransactionId(index: number, item: TransactionHistory): string {
    return item.id;
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
}