import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { StoreService } from 'src/app/services/store.service';

export interface DebtProduct {
  id?: string;
  firestoreId?: string;
  items: any[];
  total: number;
  paymentMethod: 'debt';
  customerName: string;
  customerPhone: string;
  dueDate: any;
  status: 'pending' | 'paid' | 'overdue';
  receipt_image: string;
  created_at: any;
  store_owner_id: string;
  employee_id: string;
  initialPayment?: number;
  remainingBalance?: number;
  originalTotal?: number;
  payment_status: 'unpaid' | 'partially_paid' | 'paid';
  payments?: PaymentHistory[];
  
  // Store information
  storeName?: string;
  storeProfileImage?: string;
  storeColor?: string;
  storeInitials?: string;
  storeAddress?: string;
  storeContact?: string;
  
  // Additional fields for customer view
  isOverdue?: boolean;
  daysUntilDue?: number;
}

export interface PaymentHistory {
  amount: number;
  paymentDate: any;
  receipt_image?: string;
  paid_by?: string;
  notes?: string;
}

export interface PaymentReceiptData {
  storeInfo: {
    name: string;
    address: string;
    contact: string;
    logo?: string;
  };
  customerInfo: {
    name: string;
    phone: string;
    address?: string;
  };
  paymentDetails: {
    receiptNumber: string;
    transactionDate: Date;
    paymentDate: Date;
    previousBalance: number;
    paymentAmount: number;
    newBalance: number;
    paymentMethod: string;
    cashierName: string;
  };
  debtDetails: {
    originalTransactionId: string;
    originalDate: Date;
    totalAmount: number;
    initialPayment: number;
    remainingBeforePayment: number;
  };
  paymentHistory?: PaymentHistory[];
}

@Component({
  selector: 'app-customer-tab2',
  templateUrl: './tab2.page.html',
  styleUrls: ['./tab2.page.scss'],
  standalone: false,
})
export class Tab2Page implements OnInit {
  debtProducts: DebtProduct[] = [];
  selectedDebtProduct: DebtProduct | null = null;
  showDebtReceiptModal = false;
  
  // Search and filter
  searchTerm: string = '';
  statusFilter: string = 'all';
  searchTimeout: any;

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
    await this.loadDebtsData();
  }

  async loadDebtsData() {
    const loading = await this.loadingController.create({
      message: 'Loading your debts...'
    });
    await loading.present();

    try {
      await this.loadDebtProducts();
    } catch (error) {
      console.error('Error loading debts data:', error);
      this.showToast('Error loading your debts', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  async loadDebtProducts() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      if (!customerName) {
        throw new Error('User not authenticated');
      }

      console.log('🔄 Loading debts for customer:', customerName);

      const debtProductsRef = collection(this.firestore, 'debt_products');
      
      const q = query(
        debtProductsRef,
        where('customerName', '==', customerName)
      );
      
      const querySnapshot = await getDocs(q);
      
      const debtProducts: DebtProduct[] = [];

      for (const doc of querySnapshot.docs) {
        const data = doc.data();
        
        // Get store information
        const storeInfo = await this.getStoreInfo(data['store_owner_id']);
        
        // Calculate remaining balance
        const remainingBalance = data['remainingBalance'] !== undefined 
          ? data['remainingBalance'] 
          : data['total'] || 0;

        // Check if overdue
        const dueDate = data['dueDate']?.toDate ? data['dueDate'].toDate() : new Date(data['dueDate']);
        const today = new Date();
        const isOverdue = dueDate < today && data['payment_status'] !== 'paid';

        const debtProduct: DebtProduct = {
          // Required properties from Firestore
          items: data['items'] || [],
          total: data['total'] || 0,
          paymentMethod: data['paymentMethod'] || 'debt',
          customerName: data['customerName'] || '',
          customerPhone: data['customerPhone'] || '',
          dueDate: data['dueDate'] || null,
          status: data['status'] || 'pending',
          receipt_image: data['receipt_image'] || '',
          created_at: data['created_at'] || null,
          store_owner_id: data['store_owner_id'] || '',
          employee_id: data['employee_id'] || '',
          payment_status: data['payment_status'] || 'unpaid',
          
          // Document IDs
          id: data['id'],
          firestoreId: doc.id,
          
          // Financial details
          initialPayment: data['initialPayment'] || 0,
          remainingBalance: remainingBalance,
          originalTotal: data['originalTotal'] || data['total'] || 0,
          payments: data['payments'] || [],
          
          // Store information
          storeName: storeInfo.storeName,
          storeProfileImage: storeInfo.storeProfileImage,
          storeColor: storeInfo.storeColor,
          storeInitials: storeInfo.storeInitials,
          storeAddress: storeInfo.storeAddress,
          storeContact: storeInfo.storeContact,
          
          // Status calculations
          isOverdue: isOverdue,
          daysUntilDue: this.calculateDaysUntilDue(dueDate)
        };

        debtProducts.push(debtProduct);
        
        console.log('📋 Loaded Debt:', {
          store: debtProduct.storeName,
          total: debtProduct.total,
          remaining: debtProduct.remainingBalance,
          status: debtProduct.payment_status,
          overdue: debtProduct.isOverdue
        });
      }

      // Sort by due date (overdue first, then by due date)
      this.debtProducts = debtProducts.sort((a, b) => {
        // Overdue debts first
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        
        // Then by due date (soonest first)
        const dateA = a.dueDate?.toDate ? a.dueDate.toDate() : new Date(a.dueDate);
        const dateB = b.dueDate?.toDate ? b.dueDate.toDate() : new Date(b.dueDate);
        return dateA.getTime() - dateB.getTime();
      });

      console.log(`✅ Loaded ${this.debtProducts.length} debt records`);
    } catch (error) {
      console.error('Error loading debt products:', error);
      await this.loadDebtProductsFallback();
    }
  }

  private async getStoreInfo(storeOwnerId: string): Promise<any> {
    try {
      if (!storeOwnerId) {
        return this.getDefaultStoreInfo();
      }

      // Get store profile
      const storeProfile = await this.storeService.getStoreProfile(storeOwnerId);
      
      // Get store owner info for store name
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

  private calculateDaysUntilDue(dueDate: any): number {
    if (!dueDate) return 0;
    
    const due = dueDate.toDate ? dueDate.toDate() : new Date(dueDate);
    const today = new Date();
    const diffTime = due.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    return diffDays;
  }

  async loadDebtProductsFallback() {
    try {
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const querySnapshot = await getDocs(debtProductsRef);
      
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      // Filter manually on client side
      const debtProducts = [];
      
      for (const doc of querySnapshot.docs) {
        const data = doc.data();
        if (data['customerName'] === customerName) {
          const storeInfo = await this.getStoreInfo(data['store_owner_id']);
          
          const remainingBalance = data['remainingBalance'] !== undefined 
            ? data['remainingBalance'] 
            : data['total'] || 0;

          const dueDate = data['dueDate']?.toDate ? data['dueDate'].toDate() : new Date(data['dueDate']);
          const today = new Date();
          const isOverdue = dueDate < today && data['payment_status'] !== 'paid';

          const debtProduct: DebtProduct = {
            items: data['items'] || [],
            total: data['total'] || 0,
            paymentMethod: data['paymentMethod'] || 'debt',
            customerName: data['customerName'] || '',
            customerPhone: data['customerPhone'] || '',
            dueDate: data['dueDate'] || null,
            status: data['status'] || 'pending',
            receipt_image: data['receipt_image'] || '',
            created_at: data['created_at'] || null,
            store_owner_id: data['store_owner_id'] || '',
            employee_id: data['employee_id'] || '',
            payment_status: data['payment_status'] || 'unpaid',
            id: data['id'],
            firestoreId: doc.id,
            initialPayment: data['initialPayment'] || 0,
            remainingBalance: remainingBalance,
            originalTotal: data['originalTotal'] || data['total'] || 0,
            payments: data['payments'] || [],
            storeName: storeInfo.storeName,
            storeProfileImage: storeInfo.storeProfileImage,
            storeColor: storeInfo.storeColor,
            storeInitials: storeInfo.storeInitials,
            storeAddress: storeInfo.storeAddress,
            storeContact: storeInfo.storeContact,
            isOverdue: isOverdue,
            daysUntilDue: this.calculateDaysUntilDue(dueDate)
          };

          debtProducts.push(debtProduct);
        }
      }

      this.debtProducts = debtProducts.sort((a, b) => {
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        
        const dateA = a.dueDate?.toDate ? a.dueDate.toDate() : new Date(a.dueDate);
        const dateB = b.dueDate?.toDate ? b.dueDate.toDate() : new Date(b.dueDate);
        return dateA.getTime() - dateB.getTime();
      });

      console.log(`✅ Loaded ${this.debtProducts.length} debt records (fallback)`);
    } catch (error) {
      console.error('Error in debt products fallback:', error);
      this.debtProducts = [];
    }
  }

  // View Debt Receipt
  viewDebtReceipt(debtProduct: DebtProduct) {
    this.selectedDebtProduct = debtProduct;
    this.showDebtReceiptModal = true;
  }

  closeDebtReceiptModal() {
    this.showDebtReceiptModal = false;
    this.selectedDebtProduct = null;
  }

  // Download Receipt
  async downloadReceipt(debtProduct: DebtProduct) {
    const loading = await this.loadingController.create({
      message: 'Preparing receipt for download...'
    });
    await loading.present();

    try {
      if (debtProduct.receipt_image) {
        // Download receipt image
        await this.downloadImage(debtProduct.receipt_image, `receipt-${debtProduct.id}.png`);
      } else {
        // Generate and download PDF receipt
        await this.generatePDFReceipt(debtProduct);
      }
      
      this.showToast('Receipt downloaded successfully', 'success');
    } catch (error) {
      console.error('Error downloading receipt:', error);
      this.showToast('Error downloading receipt', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  private async downloadImage(imageUrl: string, filename: string) {
    try {
      const response = await fetch(imageUrl);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      window.URL.revokeObjectURL(url);
    } catch (error) {
      throw new Error('Failed to download image');
    }
  }

  private async generatePDFReceipt(debtProduct: DebtProduct) {
    // This would integrate with a PDF generation service
    // For now, we'll create a simple text-based receipt
    const receiptText = this.generateReceiptText(debtProduct);
    
    const blob = new Blob([receiptText], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    
    const link = document.createElement('a');
    link.href = url;
    link.download = `debt-receipt-${debtProduct.id}.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    window.URL.revokeObjectURL(url);
  }

  private generateReceiptText(debtProduct: DebtProduct): string {
    return `
DEBT RECEIPT
============

Store: ${debtProduct.storeName}
Transaction ID: ${debtProduct.id}
Date: ${this.formatDate(debtProduct.created_at)}

Customer: ${debtProduct.customerName}
Phone: ${debtProduct.customerPhone}

ITEMS:
${debtProduct.items.map(item => 
  `- ${item.product_name || item.name}: ${item.quantity} x ${this.formatCurrency(item.price)} = ${this.formatCurrency(item.quantity * item.price)}`
).join('\n')}

TOTAL: ${this.formatCurrency(debtProduct.total)}
Initial Payment: ${this.formatCurrency(debtProduct.initialPayment || 0)}
Remaining Balance: ${this.formatCurrency(debtProduct.remainingBalance || debtProduct.total)}

Due Date: ${this.formatDate(debtProduct.dueDate)}
Status: ${this.getPaymentStatusText(debtProduct.payment_status)}
${debtProduct.isOverdue ? 'STATUS: OVERDUE' : ''}

Store Contact: ${debtProduct.storeContact}
Store Address: ${debtProduct.storeAddress}

Generated on: ${new Date().toLocaleDateString()}
    `.trim();
  }

  // Generate Payment Transaction Receipt as Image
  async generatePaymentReceiptImage(debtProduct: DebtProduct, paymentIndex?: number) {
    const loading = await this.loadingController.create({
      message: 'Generating payment receipt...'
    });
    await loading.present();

    try {
      if (paymentIndex !== undefined) {
        // Generate receipt for specific payment
        await this.generateSinglePaymentReceipt(debtProduct, paymentIndex);
      } else {
        // Let user choose which payment to generate receipt for
        await this.selectPaymentForReceipt(debtProduct);
      }
    } catch (error) {
      console.error('Error generating payment receipt:', error);
      this.showToast('Error generating payment receipt', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  private async selectPaymentForReceipt(debtProduct: DebtProduct) {
    if (!debtProduct.payments || debtProduct.payments.length === 0) {
      this.showToast('No payment history available', 'warning');
      return;
    }

    const alert = await this.alertController.create({
      header: 'Generate Payment Receipt',
      message: 'Select payment to generate receipt for:',
      inputs: debtProduct.payments.map((payment, index) => ({
        name: `payment-${index}`,
        type: 'radio',
        label: `${this.formatCurrency(payment.amount)} - ${this.formatDate(payment.paymentDate)}`,
        value: index.toString(),
        checked: index === 0
      })),
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Generate Receipt',
          handler: (selectedIndex) => {
            if (selectedIndex !== undefined) {
              this.generateSinglePaymentReceipt(debtProduct, parseInt(selectedIndex));
            }
          }
        }
      ]
    });

    await alert.present();
  }

  private async generateSinglePaymentReceipt(debtProduct: DebtProduct, paymentIndex: number) {
    const payment = debtProduct.payments![paymentIndex];
    const receiptData = await this.preparePaymentReceiptData(debtProduct, payment, paymentIndex);
    
    // Generate receipt as image
    await this.generateReceiptImage(receiptData, `payment-receipt-${debtProduct.id}-${paymentIndex + 1}.png`);
    
    this.showToast('Payment receipt generated successfully', 'success');
  }

  private async preparePaymentReceiptData(
    debtProduct: DebtProduct, 
    payment: PaymentHistory, 
    paymentIndex: number
  ): Promise<PaymentReceiptData> {
    const currentUser = this.authService.getCurrentUser();
    const storeInfo = await this.getStoreInfo(debtProduct.store_owner_id);
    
    // Calculate balances
    const paymentsBeforeThis = debtProduct.payments?.slice(0, paymentIndex) || [];
    const totalPaidBefore = paymentsBeforeThis.reduce((sum, p) => sum + p.amount, 0);
    const previousBalance = debtProduct.total - totalPaidBefore;
    const newBalance = previousBalance - payment.amount;

    // Get customer address from user data
    const customerAddress = currentUser ? 
      `${currentUser.barangay}, ${currentUser.municipality}, ${currentUser.province}` : 
      'Address not available';

    return {
      storeInfo: {
        name: storeInfo.storeName,
        address: storeInfo.storeAddress,
        contact: storeInfo.storeContact,
        logo: storeInfo.storeProfileImage
      },
      customerInfo: {
        name: debtProduct.customerName,
        phone: debtProduct.customerPhone,
        address: customerAddress
      },
      paymentDetails: {
        receiptNumber: `PAY-${debtProduct.id}-${paymentIndex + 1}`,
        transactionDate: debtProduct.created_at?.toDate ? debtProduct.created_at.toDate() : new Date(debtProduct.created_at),
        paymentDate: payment.paymentDate?.toDate ? payment.paymentDate.toDate() : new Date(payment.paymentDate),
        previousBalance: previousBalance,
        paymentAmount: payment.amount,
        newBalance: newBalance,
        paymentMethod: 'Cash',
        cashierName: payment.paid_by || 'Store Employee'
      },
      debtDetails: {
        originalTransactionId: debtProduct.id || 'N/A',
        originalDate: debtProduct.created_at?.toDate ? debtProduct.created_at.toDate() : new Date(debtProduct.created_at),
        totalAmount: debtProduct.total,
        initialPayment: debtProduct.initialPayment || 0,
        remainingBeforePayment: previousBalance
      },
      paymentHistory: debtProduct.payments?.slice(0, paymentIndex + 1) || []
    };
  }

  private async generateReceiptImage(receiptData: PaymentReceiptData, filename: string): Promise<void> {
    // Create canvas for receipt
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d')!;
    
    // Set canvas size (thermal receipt size)
    canvas.width = 576; // 72mm * 8 pixels per mm
    canvas.height = 800;
    
    // Set background
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Set styles
    ctx.fillStyle = '#000000';
    ctx.font = 'bold 24px Arial';
    ctx.textAlign = 'center';
    
    // Draw header
    ctx.fillText('PAYMENT RECEIPT', canvas.width / 2, 40);
    
    // Draw store info
    ctx.font = 'bold 18px Arial';
    ctx.fillText(receiptData.storeInfo.name, canvas.width / 2, 70);
    ctx.font = '14px Arial';
    ctx.fillText(receiptData.storeInfo.address, canvas.width / 2, 90);
    ctx.fillText(`Contact: ${receiptData.storeInfo.contact}`, canvas.width / 2, 110);
    
    // Draw separator
    this.drawSeparator(ctx, canvas.width, 130);
    
    // Draw receipt number and dates
    ctx.textAlign = 'left';
    ctx.font = '12px Arial';
    ctx.fillText(`Receipt: ${receiptData.paymentDetails.receiptNumber}`, 20, 160);
    ctx.fillText(`Payment Date: ${this.formatDate(receiptData.paymentDetails.paymentDate)}`, 20, 180);
    ctx.fillText(`Processed By: ${receiptData.paymentDetails.cashierName}`, 20, 200);
    
    // Draw customer info
    ctx.font = 'bold 14px Arial';
    ctx.fillText('Customer Information:', 20, 230);
    ctx.font = '12px Arial';
    ctx.fillText(`Name: ${receiptData.customerInfo.name}`, 20, 250);
    ctx.fillText(`Phone: ${receiptData.customerInfo.phone}`, 20, 270);
    
    // Draw separator
    this.drawSeparator(ctx, canvas.width, 290);
    
    // Draw payment details
    ctx.font = 'bold 16px Arial';
    ctx.fillText('PAYMENT DETAILS', canvas.width / 2, 320);
    
    ctx.textAlign = 'left';
    ctx.font = '14px Arial';
    ctx.fillText('Previous Balance:', 20, 350);
    ctx.fillText(this.formatCurrency(receiptData.paymentDetails.previousBalance), canvas.width - 120, 350);
    
    ctx.fillText('Payment Amount:', 20, 375);
    ctx.fillStyle = '#27ae60';
    ctx.fillText(`- ${this.formatCurrency(receiptData.paymentDetails.paymentAmount)}`, canvas.width - 120, 375);
    ctx.fillStyle = '#000000';
    
    ctx.fillText('New Balance:', 20, 400);
    ctx.font = 'bold 14px Arial';
    ctx.fillText(this.formatCurrency(receiptData.paymentDetails.newBalance), canvas.width - 120, 400);
    
    // Draw debt info
    this.drawSeparator(ctx, canvas.width, 430);
    ctx.font = 'bold 14px Arial';
    ctx.fillText('Original Debt Information:', 20, 460);
    ctx.font = '12px Arial';
    ctx.fillText(`Transaction ID: ${receiptData.debtDetails.originalTransactionId}`, 20, 485);
    ctx.fillText(`Original Date: ${this.formatDate(receiptData.debtDetails.originalDate)}`, 20, 505);
    ctx.fillText(`Total Amount: ${this.formatCurrency(receiptData.debtDetails.totalAmount)}`, 20, 525);
    ctx.fillText(`Initial Payment: ${this.formatCurrency(receiptData.debtDetails.initialPayment)}`, 20, 545);
    
    // Draw payment history if any
    if (receiptData.paymentHistory && receiptData.paymentHistory.length > 0) {
      this.drawSeparator(ctx, canvas.width, 570);
      ctx.font = 'bold 14px Arial';
      ctx.fillText('Payment History:', 20, 600);
      
      let yPos = 625;
      receiptData.paymentHistory.forEach((payment, index) => {
        if (yPos < canvas.height - 100) {
          ctx.font = '12px Arial';
          ctx.fillText(`${index + 1}. ${this.formatDate(payment.paymentDate)}`, 20, yPos);
          ctx.fillText(this.formatCurrency(payment.amount), canvas.width - 120, yPos);
          yPos += 20;
        }
      });
    }
    
    // Draw footer
    this.drawSeparator(ctx, canvas.width, canvas.height - 80);
    ctx.font = '10px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('Thank you for your payment!', canvas.width / 2, canvas.height - 50);
    ctx.fillText('Keep this receipt for your records', canvas.width / 2, canvas.height - 30);
    ctx.fillText(`Generated: ${new Date().toLocaleDateString()}`, canvas.width / 2, canvas.height - 10);
    
    // Convert to image and download
    const dataUrl = canvas.toDataURL('image/png');
    await this.downloadImage(dataUrl, filename);
  }

  private drawSeparator(ctx: CanvasRenderingContext2D, width: number, y: number) {
    ctx.beginPath();
    ctx.moveTo(20, y);
    ctx.lineTo(width - 20, y);
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  // Generate comprehensive payment history receipt
  async generatePaymentHistoryReceipt(debtProduct: DebtProduct) {
    if (!debtProduct.payments || debtProduct.payments.length === 0) {
      this.showToast('No payment history available', 'warning');
      return;
    }

    const loading = await this.loadingController.create({
      message: 'Generating payment history receipt...'
    });
    await loading.present();

    try {
      await this.generatePaymentHistoryImage(debtProduct);
      this.showToast('Payment history receipt generated successfully', 'success');
    } catch (error) {
      console.error('Error generating payment history receipt:', error);
      this.showToast('Error generating receipt', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  private async generatePaymentHistoryImage(debtProduct: DebtProduct): Promise<void> {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d')!;
    
    // Larger canvas for payment history
    canvas.width = 576;
    canvas.height = 1200;
    
    // Set background
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Set styles
    ctx.fillStyle = '#000000';
    ctx.font = 'bold 24px Arial';
    ctx.textAlign = 'center';
    
    // Draw header
    ctx.fillText('PAYMENT HISTORY RECEIPT', canvas.width / 2, 40);
    
    // Draw store info
    ctx.font = 'bold 18px Arial';
    ctx.fillText(debtProduct.storeName!, canvas.width / 2, 70);
    ctx.font = '14px Arial';
    ctx.fillText(debtProduct.storeAddress!, canvas.width / 2, 90);
    
    // Draw separator
    this.drawSeparator(ctx, canvas.width, 110);
    
    // Draw transaction info
    ctx.textAlign = 'left';
    ctx.font = '12px Arial';
    ctx.fillText(`Transaction ID: ${debtProduct.id}`, 20, 140);
    ctx.fillText(`Customer: ${debtProduct.customerName}`, 20, 160);
    ctx.fillText(`Phone: ${debtProduct.customerPhone}`, 20, 180);
    ctx.fillText(`Original Total: ${this.formatCurrency(debtProduct.total)}`, 20, 200);
    ctx.fillText(`Current Balance: ${this.formatCurrency(debtProduct.remainingBalance || debtProduct.total)}`, 20, 220);
    
    // Draw separator
    this.drawSeparator(ctx, canvas.width, 250);
    
    // Draw payment history header
    ctx.font = 'bold 18px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('PAYMENT HISTORY', canvas.width / 2, 280);
    
    // Draw payment history
    let yPos = 320;
    debtProduct.payments!.forEach((payment, index) => {
      if (yPos < canvas.height - 100) {
        ctx.textAlign = 'left';
        ctx.font = 'bold 14px Arial';
        ctx.fillText(`Payment ${index + 1}:`, 20, yPos);
        
        ctx.font = '12px Arial';
        ctx.fillText(`Date: ${this.formatDate(payment.paymentDate)}`, 40, yPos + 20);
        ctx.fillText(`Amount: ${this.formatCurrency(payment.amount)}`, 40, yPos + 40);
        ctx.fillText(`Processed By: ${payment.paid_by || 'Store'}`, 40, yPos + 60);
        
        if (payment.notes) {
          ctx.fillText(`Notes: ${payment.notes}`, 40, yPos + 80);
          yPos += 100;
        } else {
          yPos += 80;
        }
        
        // Draw separator between payments
        if (index < debtProduct.payments!.length - 1) {
          this.drawSeparator(ctx, canvas.width, yPos - 10);
          yPos += 10;
        }
      }
    });
    
    // Draw summary
    this.drawSeparator(ctx, canvas.width, yPos + 10);
    ctx.font = 'bold 14px Arial';
    ctx.fillText('SUMMARY', canvas.width / 2, yPos + 40);
    
    const totalPaid = debtProduct.payments!.reduce((sum, payment) => sum + payment.amount, 0);
    const remainingBalance = debtProduct.total - totalPaid;
    
    ctx.textAlign = 'left';
    ctx.font = '12px Arial';
    ctx.fillText(`Total Paid: ${this.formatCurrency(totalPaid)}`, 20, yPos + 70);
    ctx.fillText(`Remaining Balance: ${this.formatCurrency(remainingBalance)}`, 20, yPos + 90);
    ctx.fillText(`Payment Status: ${this.getPaymentStatusText(debtProduct.payment_status)}`, 20, yPos + 110);
    
    // Draw footer
    this.drawSeparator(ctx, canvas.width, canvas.height - 80);
    ctx.font = '10px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('Payment History Receipt', canvas.width / 2, canvas.height - 50);
    ctx.fillText(`Generated: ${new Date().toLocaleDateString()}`, canvas.width / 2, canvas.height - 30);
    
    // Convert to image and download
    const dataUrl = canvas.toDataURL('image/png');
    await this.downloadImage(dataUrl, `payment-history-${debtProduct.id}.png`);
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

  getPaymentStatusText(paymentStatus: string): string {
    switch (paymentStatus) {
      case 'paid': return 'Paid';
      case 'partially_paid': return 'Partial';
      case 'unpaid': return 'Unpaid';
      default: return paymentStatus;
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
    return `₱${amount?.toFixed(2) || '0.00'}`;
  }

  // Filtering and Search
  get filteredDebtProducts(): DebtProduct[] {
    let filtered = this.debtProducts;

    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(product => 
        product.storeName?.toLowerCase().includes(term) ||
        product.id?.toLowerCase().includes(term) ||
        this.formatCurrency(product.total).toLowerCase().includes(term)
      );
    }

    if (this.statusFilter !== 'all') {
      filtered = filtered.filter(product => 
        this.statusFilter === 'overdue' ? 
        product.isOverdue : 
        product.payment_status === this.statusFilter
      );
    }

    return filtered;
  }

  getUniqueStoresCount(): number {
    const storeIds = new Set(this.filteredDebtProducts.map(debt => debt.store_owner_id));
    return storeIds.size;
  }

  getTotalOutstanding(): number {
    return this.debtProducts
      .filter(debt => debt.payment_status !== 'paid')
      .reduce((total, debt) => total + (debt.remainingBalance || debt.total), 0);
  }

  getOverdueTotal(): number {
    return this.debtProducts
      .filter(debt => debt.isOverdue)
      .reduce((total, debt) => total + (debt.remainingBalance || debt.total), 0);
  }

  getDebtCountByStatus(status: string): number {
    if (status === 'overdue') {
      return this.debtProducts.filter(debt => debt.isOverdue).length;
    }
    return this.debtProducts.filter(debt => debt.payment_status === status).length;
  }

  // Refresh Methods
  async doRefresh(event: any) {
    await this.loadDebtsData();
    event.target.complete();
  }

  async doRefreshManual() {
    const loading = await this.loadingController.create({
      message: 'Refreshing debts...',
      duration: 3000
    });
    
    await loading.present();
    
    try {
      await this.loadDebtsData();
      this.showToast('Debts refreshed successfully', 'success');
    } catch (error) {
      console.error('Error refreshing data:', error);
      this.showToast('Error refreshing debts', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  // Event Handlers
  segmentChanged() {
    // The getter will automatically update the view
  }

  searchChanged() {
    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      // The getter filteredDebtProducts will automatically update the view
    }, 300);
  }

  filterChanged() {
    // The getter will automatically update the view
  }

  // TrackBy for performance
  trackByDebtId(index: number, item: DebtProduct): string {
    return item.firestoreId || item.id || index.toString();
  }

  // Image error handler
  handleImageError(event: any, type: 'debt') {
    console.log('Image load error:', event);
    event.target.style.display = 'none';
  }

  // Share receipt functionality
  async shareReceipt(debtProduct: DebtProduct) {
    // This would integrate with your sharing service
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
}