import { Injectable } from '@angular/core';
import { 
  Firestore, 
  collection, 
  doc, 
  setDoc, 
  getDoc, 
  updateDoc, 
  query,
  where,
  getDocs,
  Timestamp,
  orderBy,
  limit
} from '@angular/fire/firestore';
import { HttpClient } from '@angular/common/http';
import { AuthService } from './auth.service';
import { firstValueFrom } from 'rxjs';

export interface BulkOption {
  unit: string;
  pieces: number;
  selling_price: number;
  cost_price?: number;
  is_default?: boolean;
}
export interface Product {
  id?: string;
  barcode: string;
  name: string;
  description: string;
  category: string;
  brand: string;
  stock_quantity: number;
  min_stock_level: number;
  max_stock_level: number;
  cost_price: number;
  selling_price: number;
  // Bulk pricing for sari-sari store items
  bulk_unit?: string;
  pieces_per_bulk?: number;
  bulk_selling_price?: number;
  // Enhanced bulk options for different packaging
  bulk_options?: BulkOption[];
  unit_of_measure: string;
  weight?: number;
  volume?: number;
  image_url: string;
  is_active: boolean;
  store_owner_id: string;
  created_at: any;
  updated_at: any;
  has_barcode: boolean; // NEW: Flag for barcode-less products
  custom_product_id?: string; // NEW: Custom ID for tracking
}

export interface ProductSearchResult {
  exists: boolean;
  product?: Product;
  message: string;
  barcode: string;
  source?: 'database' | 'open_food_facts' | 'barcode_lookup' | 'upcitemdb' | 'open_products_facts' | 'open_beauty_facts' | 'manual' | 'no_barcode';
}

interface CachedProductResult extends ProductSearchResult {
  cachedAt: number;
}

@Injectable({
  providedIn: 'root'
})
export class ProductService {

  // Cache for faster searches
  private productCache = new Map<string, CachedProductResult>();
  private cacheTimeout = 5 * 60 * 1000; // 5 minutes cache

  // Search index for fast local searching
  private searchIndex: Map<string, Product[]> = new Map();

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private http: HttpClient
  ) { }
  /**
 * 🔥 NEW: Get the store owner ID for the current user
 * - Store Owners use their own ID
 * - Employees use their store_owner_id
 */
/**
 * 🔥 NEW: Get the store owner ID for the current user
 * - Store Owners use their own ID
 * - Employees use their store_owner_id
 */
private getCurrentStoreOwnerId(): string | null {
  const currentUser = this.authService.getCurrentUser();
  
  if (!currentUser) {
    console.error('❌ No user logged in');
    return null;
  }

  console.log('👤 Current User:', {
    id: currentUser.id,
    role: currentUser.role,
    store_owner_id: currentUser.store_owner_id,
    full_name: currentUser.full_name
  });

  // Store Owner: use their own ID
  if (currentUser.role === 'StoreOwner') {
    console.log('🏪 Store Owner detected, using own ID:', currentUser.id);
    return currentUser.id || null;
  }

  // Employee: use their store_owner_id (NOT their own ID)
  if (currentUser.role === 'Employee') {
    if (currentUser.store_owner_id) {
      console.log('👨‍💼 Employee detected, using store owner ID:', currentUser.store_owner_id);
      return currentUser.store_owner_id;
    } else {
      console.error('❌ Employee has no store_owner_id assigned');
      return null;
    }
  }

  // Admin/Customer: not allowed to manage products
  console.warn('⚠️ User role not allowed to manage products:', currentUser.role);
  return null;
}
 /**
 * 🔥 UPDATED: Get product by barcode from local database - NOW WITH DEBUGGING
 */
/**
 * 🔥 UPDATED: Get product by barcode from local database - WITH BARCODE NORMALIZATION
 */
async getProductByBarcode(barcode: string): Promise<Product | null> {
  try {
    const storeOwnerId = this.getCurrentStoreOwnerId();
    if (!storeOwnerId) {
      throw new Error('User not authorized to view products');
    }

    console.log('🔍 Searching product by barcode:', {
      original: barcode,
      normalized: this.normalizeBarcode(barcode),
      storeOwnerId: storeOwnerId
    });

    // FIRST: Try with barcode variations (including normalized)
    const product = await this.searchWithBarcodeVariations(barcode, storeOwnerId);
    
    if (product) {
      console.log('✅ Product found with barcode variations:', product.name);
      return product;
    }

    // SECOND: If not found, run comprehensive debug
    console.log('🔄 Product not found with variations, running debug...');
    this.debugDataTypes(barcode, storeOwnerId);
    await this.debugProductSearch(barcode, storeOwnerId);

    return null;

  } catch (error) {
    console.error('❌ Error getting product by barcode:', error);
    return null;
  }
}
  /**
 * 🔥 UPDATED: Get all store products - NOW SCOPED TO STORE OWNER
 */
async getStoreProducts(): Promise<Product[]> {
  try {
    const storeOwnerId = this.getCurrentStoreOwnerId();
    if (!storeOwnerId) {
      console.warn('⚠️ No store owner ID found, returning empty array');
      return [];
    }

    console.log('📦 Loading products for store owner:', storeOwnerId);

    const productsRef = collection(this.firestore, 'products');
    const q = query(
      productsRef, 
      where('store_owner_id', '==', storeOwnerId),
      where('is_active', '==', true),
      orderBy('name')
    );
    
    const querySnapshot = await getDocs(q);
    
    const products = querySnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        // Ensure all new fields have default values
        has_barcode: data['has_barcode'] !== undefined ? data['has_barcode'] : true,
        custom_product_id: data['custom_product_id'] || '',
        bulk_options: data['bulk_options'] || [],
        ...data,
        created_at: data['created_at'],
        updated_at: data['updated_at']
      } as Product;
    });

    console.log(`✅ Loaded ${products.length} products for store owner`);

    // Pre-cache these products for faster barcode lookups
    products.forEach(product => {
      if (product.barcode) {
        this.addToCache(product.barcode, {
          exists: true,
          product: product,
          message: 'Product found in your inventory',
          barcode: product.barcode,
          source: 'database'
        });
      }
    });

    // Build search index
    this.buildSearchIndex(products);

    return products;
  } catch (error) {
    console.error('❌ Error getting store products:', error);
    throw error;
  }
}
 /**
 * 🔥 UPDATED: Create new product - NOW AUTO-SETS STORE OWNER ID
 */
async createProduct(productData: Omit<Product, 'id' | 'created_at' | 'updated_at' | 'is_active' | 'store_owner_id'>): Promise<void> {
  try {
    const storeOwnerId = this.getCurrentStoreOwnerId();
    if (!storeOwnerId) {
      throw new Error('User not authorized to create products');
    }

    console.log('🆕 Creating product for store owner:', storeOwnerId);

    // Check if product already exists FOR THIS STORE OWNER
    if (productData.has_barcode && productData.barcode) {
      // For barcode products, check by barcode
      const existingProduct = await this.getProductByBarcode(productData.barcode);
      if (existingProduct) {
        throw new Error('Product with this barcode already exists in your store');
      }
    } else if (productData.custom_product_id) {
      // For no-barcode products, check by custom_product_id
      const existingProduct = await this.getProductByCustomId(productData.custom_product_id, storeOwnerId);
      if (existingProduct) {
        throw new Error('Product with this custom ID already exists in your store');
      }
    }

    const productsRef = collection(this.firestore, 'products');
    const productDocRef = doc(productsRef);
    
    // Ensure all required fields are set
    const newProduct: Product = {
      id: productDocRef.id,
      ...productData,
      // Ensure these fields are always set
      has_barcode: productData.has_barcode !== undefined ? productData.has_barcode : true,
      custom_product_id: productData.custom_product_id || '',
      bulk_options: productData.bulk_options || [],
      is_active: true,
      store_owner_id: storeOwnerId,
      created_at: Timestamp.now(),
      updated_at: Timestamp.now()
    };

    await setDoc(productDocRef, newProduct);
    console.log('✅ Product created successfully:', newProduct.name, 'for store owner:', storeOwnerId);
    
    // Clear cache to ensure fresh data
    this.clearCache();
    
  } catch (error: any) {
    console.error('❌ Error creating product:', error);
    throw error;
  }
}
/**
 * 🔥 NEW: Get product by custom ID for no-barcode products
 */
async getProductByCustomId(customId: string, storeOwnerId: string): Promise<Product | null> {
  try {
    console.log('🔍 Searching product by custom ID:', {
      customId: customId,
      storeOwnerId: storeOwnerId
    });

    const productsRef = collection(this.firestore, 'products');
    const q = query(
      productsRef, 
      where('custom_product_id', '==', customId),
      where('store_owner_id', '==', storeOwnerId),
      where('is_active', '==', true)
    );
    
    const querySnapshot = await getDocs(q);
    
    if (!querySnapshot.empty) {
      const doc = querySnapshot.docs[0];
      const productData = doc.data();
      
      const product = { 
        id: doc.id, 
        ...productData,
        created_at: productData['created_at'],
        updated_at: productData['updated_at']
      } as Product;

      console.log('✅ Product found with custom ID:', product.name);
      return product;
    }
    
    console.log('❌ No product found with custom ID:', customId);
    return null;
    
  } catch (error) {
    console.error('❌ Error getting product by custom ID:', error);
    return null;
  }
}

/**
 * 🔥 UPDATED: Search or create product by barcode - WITH BARCODE NORMALIZATION
 */
async searchOrCreateProductByBarcode(barcode: string): Promise<ProductSearchResult> {
  // Clean the barcode first
  const cleanBarcode = barcode.trim();
  const normalizedBarcode = this.normalizeBarcode(cleanBarcode);
  
  console.log('🔍 DEBUG: Starting search with barcode:', {
    original: barcode,
    clean: cleanBarcode,
    normalized: normalizedBarcode
  });
  
  // Check cache first (using normalized barcode)
  const cachedResult = this.getFromCache(normalizedBarcode);
  if (cachedResult) {
    console.log('⚡ Using cached result for:', normalizedBarcode, {
      exists: cachedResult.exists,
      source: cachedResult.source
    });
    return cachedResult;
  }

  try {
    const storeOwnerId = this.getCurrentStoreOwnerId();
    if (!storeOwnerId) {
      throw new Error('User not authorized to search products');
    }

    console.log('🔍 DEBUG: Store context:', {
      originalBarcode: barcode,
      normalizedBarcode: normalizedBarcode,
      storeOwnerId: storeOwnerId
    });

    // First, check if product already exists in OUR STORE'S database
    // USING THE NEW METHOD THAT TRIES MULTIPLE VARIATIONS
    const existingProduct = await this.getProductByBarcode(barcode);
    
    console.log('🔍 DEBUG: Existing product check result:', {
      found: !!existingProduct,
      barcodeUsed: normalizedBarcode,
      product: existingProduct ? {
        id: existingProduct.id,
        name: existingProduct.name,
        barcode: existingProduct.barcode, // This shows what's actually stored
        store_owner_id: existingProduct.store_owner_id
      } : null
    });

    if (existingProduct) {
      console.log('✅ Product found in local store database:', existingProduct.name);
      const result: ProductSearchResult = {
        exists: true,
        product: existingProduct,
        message: 'Product found in your store inventory',
        barcode: normalizedBarcode,
        source: 'database'
      };
      this.addToCache(normalizedBarcode, result);
      return result;
    }

    console.log('🔄 Product not in local store database, checking external APIs...');

    // If not found, lookup from external APIs
    const lookupResult = await this.lookupProductByBarcode(normalizedBarcode);
    
    if (lookupResult.success && lookupResult.product) {
      console.log('✅ Product found in external database');
      
      const productTemplate: Product = {
        barcode: normalizedBarcode, // Use normalized barcode
        name: lookupResult.product.name,
        description: lookupResult.product.description,
        category: lookupResult.product.category,
        brand: lookupResult.product.brand,
        stock_quantity: 0,
        min_stock_level: 10,
        max_stock_level: 100,
        cost_price: 0,
        selling_price: 0,
        unit_of_measure: 'piece',
        image_url: lookupResult.product.image_url,
        is_active: true,
        store_owner_id: storeOwnerId,
        created_at: Timestamp.now(),
        updated_at: Timestamp.now(),
        has_barcode: true, // ADD THIS - indicates this product has a barcode
        custom_product_id: '', // ADD THIS - empty for barcode products
        bulk_options: [] // ADD THIS - initialize empty array
      };

      const result: ProductSearchResult = {
        exists: false,
        product: productTemplate,
        message: lookupResult.message,
        barcode: normalizedBarcode,
        source: lookupResult.source as any
      };
      this.addToCache(normalizedBarcode, result);
      return result;
    } else {
      console.log('❌ Product not found anywhere, creating manual template');
      // Product not found anywhere, create a basic template
      const manualProduct: Product = {
        barcode: normalizedBarcode, // Use normalized barcode
        name: `Product ${normalizedBarcode}`,
        description: `Product with barcode ${normalizedBarcode}`,
        category: 'Uncategorized',
        brand: 'Unknown Brand',
        stock_quantity: 0,
        min_stock_level: 10,
        max_stock_level: 100,
        cost_price: 0,
        selling_price: 0,
        unit_of_measure: 'piece',
        image_url: '',
        is_active: true,
        store_owner_id: storeOwnerId,
        created_at: Timestamp.now(),
        updated_at: Timestamp.now(),
        has_barcode: true, // ADD THIS - indicates this product has a barcode
        custom_product_id: '', // ADD THIS - empty for barcode products
        bulk_options: [] // ADD THIS - initialize empty array
      };

      const result: ProductSearchResult = {
        exists: false,
        product: manualProduct,
        message: 'New product - please complete the information',
        barcode: normalizedBarcode,
        source: 'manual'
      };
      this.addToCache(normalizedBarcode, result);
      return result;
    }

  } catch (error: any) {
    console.error('❌ Error searching product by barcode:', error);
    throw new Error('Failed to search product: ' + error.message);
  }
}

  /**
   * 🔥 UPDATED: Get low stock products - NOW SCOPED TO STORE OWNER
   */
  async getLowStockProducts(): Promise<Product[]> {
    try {
      const products = await this.getStoreProducts();
      return products.filter(product => 
        product.stock_quantity <= product.min_stock_level && product.stock_quantity > 0
      );
    } catch (error) {
      console.error('❌ Error getting low stock products:', error);
      throw error;
    }
  }

  // ========== EVERYTHING BELOW THIS LINE REMAINS EXACTLY THE SAME ==========

  /**
   * Enhanced lookup with better error handling
   */
  async lookupProductByBarcode(barcode: string): Promise<{success: boolean; product?: any; message: string; source: string}> {
    try {
      console.log('🔍 Enhanced lookup for barcode:', barcode);

      // Try multiple APIs with better sequencing for comprehensive coverage
      const apis = [
        { 
          name: 'Open Beauty Facts', 
          method: this.tryOpenBeautyFacts.bind(this),
          priority: 1 // Start with beauty facts since you mentioned it works
        },
        { 
          name: 'Open Products Facts', 
          method: this.tryOpenProductsFacts.bind(this),
          priority: 2
        },
        { 
          name: 'Open Food Facts', 
          method: this.tryOpenFoodFacts.bind(this),
          priority: 3
        },
        { 
          name: 'UPCitemdb', 
          method: this.tryUPCitemdb.bind(this),
          priority: 4 // These might have CORS issues
        },
        { 
          name: 'Barcode Lookup', 
          method: this.tryBarcodeLookup.bind(this),
          priority: 5 // These might have CORS issues
        }
      ];

      // Sort by priority
      apis.sort((a, b) => a.priority - b.priority);

      for (const api of apis) {
        console.log(`🔄 Trying ${api.name}...`);
        try {
          const result = await api.method(barcode);
          if (result.success) {
            console.log(`✅ Product found in ${api.name}`);
            
            // Enhance the product data with better category detection
            if (result.product) {
              result.product = this.enhanceProductData(result.product, barcode);
            }
            
            return { ...result, source: api.name.toLowerCase().replace(/ /g, '_') };
          }
        } catch (error) {
          console.log(`❌ ${api.name} failed:`, error);
          // Continue to next API
        }
      }

      console.log('❌ Product not found in any database');
      return {
        success: false,
        message: 'Product not found in any product database',
        source: 'none'
      };

    } catch (error: any) {
      console.error('❌ Barcode lookup error:', error);
      return {
        success: false,
        message: `Error looking up product: ${error.message}`,
        source: 'error'
      };
    }
  }

  /**
   * NEW: Try Open Products Facts API (for non-food items)
   */
  private async tryOpenProductsFacts(barcode: string): Promise<{success: boolean; product?: any; message: string}> {
    try {
      const response = await firstValueFrom(
        this.http.get<any>(`https://world.openproductsfacts.org/api/v2/product/${barcode}`)
      );

      if (response.status === 'success' && response.product) {
        const product = response.product;
        
        const productInfo = {
          name: this.enhanceProductName(product.product_name || product.product_name_en || `Product ${barcode}`, barcode),
          brand: this.enhanceBrandName(product.brands || product.brand_owner || 'Unknown Brand'),
          category: this.enhanceCategoryDetection(
            product.categories, 
            product.product_name, 
            product.generic_name,
            product.brands
          ),
          description: product.generic_name || product.product_name || `Product with barcode ${barcode}`,
          image_url: product.image_url || product.image_front_url || product.selected_images?.front?.display?.en || '',
          weight: product.quantity || this.extractWeight(product.product_name || ''),
          size: this.extractSize(product.product_name || '')
        };

        return {
          success: true,
          product: productInfo,
          message: 'Product information retrieved from Open Products Facts'
        };
      }
      return { success: false, message: 'Not found in Open Products Facts' };
    } catch (error) {
      console.log('Open Products Facts not available or product not found');
      return { success: false, message: 'Open Products Facts API error' };
    }
  }

  /**
   * NEW: Try Open Beauty Facts API (for beauty and personal care items)
   */
  private async tryOpenBeautyFacts(barcode: string): Promise<{success: boolean; product?: any; message: string}> {
    try {
      console.log(`🔍 Trying Open Beauty Facts for barcode: ${barcode}`);
      
      const response = await firstValueFrom(
        this.http.get<any>(`https://world.openbeautyfacts.org/api/v2/product/${barcode}`, {
          // Add headers to handle CORS better
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'YourApp/1.0'
          }
        })
      );

      console.log('📦 Open Beauty Facts Response:', response);

      // FIX: Check the actual response structure
      if (response && response.product) {
        const product = response.product;
        
        const productInfo = {
          name: this.enhanceProductName(
            product.product_name || 
            product.product_name_en || 
            product.product_name_fr || 
            `Product ${barcode}`, 
            barcode
          ),
          brand: this.enhanceBrandName(
            product.brands || 
            product.brand_owner || 
            product.brand || 
            'Unknown Brand'
          ),
          category: this.enhanceCategoryDetection(
            product.categories, 
            product.product_name, 
            product.generic_name,
            product.brands
          ),
          description: product.generic_name || 
                      product.product_name || 
                      `Product with barcode ${barcode}`,
          image_url: product.image_url || 
                    product.image_front_url || 
                    product.image_front_small_url ||
                    (product.selected_images?.front?.display?.en || ''),
          weight: product.quantity || this.extractWeight(product.product_name || ''),
          size: this.extractSize(product.product_name || '')
        };

        console.log('✅ Product found in Open Beauty Facts:', productInfo);

        return {
          success: true,
          product: productInfo,
          message: 'Product information retrieved from Open Beauty Facts'
        };
      }
      
      console.log('❌ Product not found in Open Beauty Facts');
      return { success: false, message: 'Not found in Open Beauty Facts' };
      
    } catch (error: any) {
      console.error('❌ Open Beauty Facts API error:', error);
      
      // Provide more specific error messages
      if (error.status === 404) {
        return { success: false, message: 'Product not found in Open Beauty Facts' };
      } else if (error.status === 0 || error.name === 'HttpErrorResponse') {
        return { success: false, message: 'Network error - cannot reach Open Beauty Facts' };
      } else {
        return { success: false, message: `Open Beauty Facts API error: ${error.message}` };
      }
    }
  }

  /**
   * Try Open Food Facts API (mainly food items)
   */
  private async tryOpenFoodFacts(barcode: string): Promise<{success: boolean; product?: any; message: string}> {
    try {
      const response = await firstValueFrom(
        this.http.get<any>(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`)
      );

      if (response.status === 1 && response.product) {
        const product = response.product;
        
        const productInfo = {
          name: this.cleanProductName(product.product_name || product.product_name_en || `Product ${barcode}`),
          brand: this.cleanBrandName(product.brands || product.brand_owner || 'Unknown Brand'),
          category: this.determineCategory(product.categories, product.categories_tags),
          description: product.generic_name || product.product_name || `Product with barcode ${barcode}`,
          image_url: product.image_url || product.image_front_url || (product.selected_images?.front?.display?.en || '')
        };

        // Add quantity/packaging info
        if (product.quantity) {
          productInfo.description += ` | ${product.quantity}`;
        }
        if (product.packaging) {
          productInfo.description += ` | Packaged in: ${product.packaging}`;
        }

        return {
          success: true,
          product: productInfo,
          message: 'Product information retrieved from Open Food Facts'
        };
      }
      return { success: false, message: 'Not found in Open Food Facts' };
    } catch (error) {
      return { success: false, message: 'Open Food Facts API error' };
    }
  }

  /**
   * Try UPCitemdb API (covers both food and non-food)
   */
  private async tryUPCitemdb(barcode: string): Promise<{success: boolean; product?: any; message: string}> {
    try {
      const response = await firstValueFrom(
        this.http.get<any>(`https://api.upcitemdb.com/prod/trial/lookup?upc=${barcode}`)
      );

      if (response.code === 'OK' && response.items && response.items.length > 0) {
        const item = response.items[0];
        
        // Extract additional product details
        const productInfo = {
          name: this.enhanceProductName(item.title || `Product ${barcode}`, barcode),
          brand: this.enhanceBrandName(item.brand || item.manufacturer || 'Unknown Brand'),
          category: this.determineCategory(item.category || item.description),
          description: item.description || `Product with barcode ${barcode}`,
          image_url: item.images && item.images.length > 0 ? item.images[0] : '',
          // Additional fields for better product info
          weight: this.extractWeight(item.title || item.description),
          size: this.extractSize(item.title || item.description)
        };

        return {
          success: true,
          product: productInfo,
          message: 'Product information retrieved from UPCitemdb'
        };
      }
      return { success: false, message: 'Not found in UPCitemdb' };
    } catch (error) {
      return { success: false, message: 'UPCitemdb API error' };
    }
  }

  /**
   * Try Barcode Lookup API (comprehensive coverage)
   */
  private async tryBarcodeLookup(barcode: string): Promise<{success: boolean; product?: any; message: string}> {
    try {
      // Note: You'll need to get a free API key from barcodelookup.com for production
      const apiKey = '6ce6j91pvrcvtxvfgca8bbudt44578'; // Use 'demo' for testing, get real key for production
      const response = await firstValueFrom(
        this.http.get<any>(`https://api.barcodelookup.com/v3/products?barcode=${barcode}&formatted=y&key=${apiKey}`)
      );

      if (response.products && response.products.length > 0) {
        const product = response.products[0];
        
        const productInfo = {
          name: this.cleanProductName(product.product_name || product.title || `Product ${barcode}`),
          brand: this.cleanBrandName(product.brand || product.manufacturer || 'Unknown Brand'),
          category: this.determineCategory(product.category),
          description: product.description || `Product with barcode ${barcode}`,
          image_url: product.images && product.images.length > 0 ? product.images[0] : ''
        };

        return {
          success: true,
          product: productInfo,
          message: 'Product information retrieved from Barcode Lookup API'
        };
      }
      return { success: false, message: 'Not found in Barcode Lookup API' };
    } catch (error) {
      return { success: false, message: 'Barcode Lookup API error' };
    }
  }

  /**
   * Enhance product data with better categorization and information
   */
  private enhanceProductData(product: any, barcode: string): any {
    const enhancedProduct = { ...product };
    
    // Improve category detection
    enhancedProduct.category = this.enhanceCategoryDetection(
      product.category, 
      product.name, 
      product.description,
      product.brand
    );
    
    // Clean and standardize names
    enhancedProduct.name = this.enhanceProductName(product.name, barcode);
    enhancedProduct.brand = this.enhanceBrandName(product.brand);
    
    // Add missing descriptions
    if (!enhancedProduct.description || enhancedProduct.description === `Product with barcode ${barcode}`) {
      enhancedProduct.description = this.generateProductDescription(
        enhancedProduct.name,
        enhancedProduct.brand,
        enhancedProduct.category
      );
    }
    
    return enhancedProduct;
  }

  /**
   * Enhanced category detection with more non-food categories
   */
  private enhanceCategoryDetection(category: string, name: string, description: string, brand: string): string {
    const searchText = `${category} ${name} ${description} ${brand}`.toLowerCase();
    
    // Comprehensive category mapping
    const categoryPatterns = [
      // Food & Beverages
      { pattern: /beverage|drink|soda|juice|water|tea|coffee|energy.?drink/i, category: 'Beverages' },
      { pattern: /snack|chip|candy|chocolate|biscuit|cookie|cracker|popcorn|nut|pretzel/i, category: 'Snacks' },
      { pattern: /dairy|milk|cheese|yogurt|butter|cream|ice.?cream/i, category: 'Dairy' },
      { pattern: /meat|poultry|chicken|beef|pork|fish|seafood|sausage|bacon/i, category: 'Meat & Seafood' },
      { pattern: /vegetable|fruit|produce|apple|banana|orange|lettuce|carrot/i, category: 'Produce' },
      { pattern: /frozen|ice|freezer/i, category: 'Frozen Foods' },
      { pattern: /canned|canning|tin/i, category: 'Canned Goods' },
      { pattern: /bakery|bread|pastry|cake|pie|doughnut|muffin/i, category: 'Bakery' },
      { pattern: /grain|rice|pasta|cereal|oatmeal|flour/i, category: 'Grains & Pasta' },
      
      // Personal Care & Toiletries
      { pattern: /shampoo|conditioner|hair.?care|styling/i, category: 'Hair Care' },
      { pattern: /soap|body.?wash|hand.?wash|shower.?gel/i, category: 'Bath & Body' },
      { pattern: /toothpaste|tooth.?brush|dental|mouthwash/i, category: 'Oral Care' },
      { pattern: /deodorant|antiperspirant|body.?spray/i, category: 'Deodorants' },
      { pattern: /lotion|cream|moisturizer|skin.?care|face.?cream/i, category: 'Skin Care' },
      { pattern: /razor|shave|blade|shaving.?cream/i, category: 'Shaving' },
      { pattern: /fragrance|perfume|cologne|eau.?de.?toilette/i, category: 'Fragrances' },
      { pattern: /makeup|cosmetic|lipstick|mascara|foundation|eyeshadow/i, category: 'Cosmetics' },
      
      // Household & Cleaning
      { pattern: /detergent|laundry|fabric|softener/i, category: 'Laundry' },
      { pattern: /cleaner|disinfectant|wipe|spray|bleach/i, category: 'Cleaning Supplies' },
      { pattern: /dish.?soap|dish.?detergent|dishwasher/i, category: 'Dish Care' },
      { pattern: /paper|tissue|toilet.?paper|paper.?towel|napkin/i, category: 'Paper Products' },
      { pattern: /bag|trash.?bag|garbage.?bag|ziploc/i, category: 'Bags & Wraps' },
      { pattern: /air.?freshener|deodorizer|scent/i, category: 'Air Fresheners' },
      
      // Health & Wellness
      { pattern: /vitamin|supplement|mineral|herbal/i, category: 'Vitamins & Supplements' },
      { pattern: /pain.?relief|analgesic|headache|fever/i, category: 'Pain Relief' },
      { pattern: /cold|flu|cough|sore.?throat|decongestant/i, category: 'Cold & Flu' },
      { pattern: /first.?aid|bandage|band.?aid|antiseptic/i, category: 'First Aid' },
      { pattern: /allergy|antihistamine|sinus/i, category: 'Allergy' },
      { pattern: /digestive|antacid|stomach|laxative/i, category: 'Digestive Health' },
      
      // Baby Care
      { pattern: /diaper|nappy|baby.?wipe|baby.?care/i, category: 'Baby Diapers & Wipes' },
      { pattern: /baby.?food|formula|infant|toddler/i, category: 'Baby Food' },
      { pattern: /baby.?lotion|baby.?wash|baby.?shampoo/i, category: 'Baby Care' },
      
      // Pet Care
      { pattern: /pet.?food|dog.?food|cat.?food|pet.?treat/i, category: 'Pet Food' },
      { pattern: /pet.?care|cat.?litter|pet.?shampoo/i, category: 'Pet Supplies' },
      
      // Electronics & Office
      { pattern: /battery|batteries|aa|aaa/i, category: 'Batteries' },
      { pattern: /light.?bulb|led|flashlight|lamp/i, category: 'Lighting' },
      { pattern: /stationery|pen|pencil|marker|notebook/i, category: 'Office Supplies' },
      
      // Hardware & Automotive
      { pattern: /tool|hardware|screw|nail|hammer/i, category: 'Hardware' },
      { pattern: /automotive|car.?care|motor.?oil|wiper.?blade/i, category: 'Automotive' }
    ];

    for (const { pattern, category } of categoryPatterns) {
      if (pattern.test(searchText)) {
        return category;
      }
    }

    return category || 'Uncategorized';
  }

  /**
   * Enhanced product name cleaning
   */
  private enhanceProductName(name: string, barcode: string): string {
    if (!name || name === `Product ${barcode}`) {
      return `Product ${barcode}`;
    }
    
    // Remove common unwanted prefixes/suffixes
    let cleanedName = name
      .replace(/^(new|improved|all.?natural|organic)\s+/i, '')
      .replace(/\s*(\(\d+\)|-\d+|\d+oz|\d+ml|\d+g|\d+ct|\d+pack)$/i, '')
      .trim();
    
    return this.capitalizeWords(cleanedName);
  }

  /**
   * Enhanced brand name cleaning
   */
  private enhanceBrandName(brand: string): string {
    if (!brand || brand === 'Unknown Brand') {
      return 'Unknown Brand';
    }
    
    // Remove common corporate suffixes
    let cleanedBrand = brand
      .replace(/\s*(inc|llc|corp|corporation|co|company|limited|ltd)\.?$/i, '')
      .trim();
    
    return this.capitalizeWords(cleanedBrand);
  }

  /**
   * Generate better product descriptions
   */
  private generateProductDescription(name: string, brand: string, category: string): string {
    if (brand !== 'Unknown Brand') {
      return `${brand} ${name} - ${category}`;
    }
    return `${name} - ${category}`;
  }

  /**
   * Extract weight information from product text
   */
  private extractWeight(text: string): string {
    const weightPatterns = [
      /(\d+(?:\.\d+)?)\s*(oz|ounce)/i,
      /(\d+(?:\.\d+)?)\s*(lb|pound)/i,
      /(\d+(?:\.\d+)?)\s*(g|gram)/i,
      /(\d+(?:\.\d+)?)\s*(kg|kilogram)/i,
      /(\d+(?:\.\d+)?)\s*(ml|milliliter)/i,
      /(\d+(?:\.\d+)?)\s*(l|liter)/i
    ];
    
    for (const pattern of weightPatterns) {
      const match = text.match(pattern);
      if (match) {
        return `${match[1]} ${match[2].toLowerCase()}`;
      }
    }
    
    return '';
  }

  /**
   * Extract size/count information from product text
   */
  private extractSize(text: string): string {
    const sizePatterns = [
      /(\d+)\s*ct/i, // count
      /(\d+)\s*pack/i, // pack
      /(\d+)\s*count/i,
      /(\d+)\s*roll/i,
      /(\d+)\s*sheet/i
    ];
    
    for (const pattern of sizePatterns) {
      const match = text.match(pattern);
      if (match) {
        return `${match[1]} ${pattern.toString().includes('ct') ? 'count' : 
                pattern.toString().includes('pack') ? 'pack' :
                pattern.toString().includes('roll') ? 'roll' :
                pattern.toString().includes('sheet') ? 'sheets' : 'count'}`;
      }
    }
    
    return '';
  }

  /**
   * Smart category determination for both food and non-food items
   */
  private determineCategory(categories: string, categoriesTags?: string[]): string {
    if (!categories) return 'Uncategorized';

    const categoryStr = categories.toLowerCase();
    
    // Food categories
    if (categoryStr.includes('beverage') || categoryStr.includes('drink') || categoryStr.includes('soda')) return 'Beverages';
    if (categoryStr.includes('snack') || categoryStr.includes('chip') || categoryStr.includes('candy') || categoryStr.includes('biscuit')) return 'Snacks';
    if (categoryStr.includes('dairy') || categoryStr.includes('milk') || categoryStr.includes('cheese') || categoryStr.includes('yogurt')) return 'Dairy';
    if (categoryStr.includes('meat') || categoryStr.includes('poultry') || categoryStr.includes('fish') || categoryStr.includes('seafood')) return 'Meat & Seafood';
    if (categoryStr.includes('vegetable') || categoryStr.includes('fruit') || categoryStr.includes('produce')) return 'Produce';
    if (categoryStr.includes('frozen')) return 'Frozen Foods';
    if (categoryStr.includes('canned') || categoryStr.includes('canning')) return 'Canned Goods';
    if (categoryStr.includes('bakery') || categoryStr.includes('bread') || categoryStr.includes('pastry')) return 'Bakery';
    
    // Non-food categories
    if (categoryStr.includes('personal care') || categoryStr.includes('cosmetic') || categoryStr.includes('beauty') || 
        categoryStr.includes('toilet') || categoryStr.includes('soap') || categoryStr.includes('shampoo')) return 'Personal Care';
    if (categoryStr.includes('household') || categoryStr.includes('clean') || categoryStr.includes('detergent') || 
        categoryStr.includes('laundry')) return 'Household';
    if (categoryStr.includes('pharma') || categoryStr.includes('medicine') || categoryStr.includes('health') || 
        categoryStr.includes('vitamin') || categoryStr.includes('supplement')) return 'Health & Wellness';
    if (categoryStr.includes('baby') || categoryStr.includes('infant') || categoryStr.includes('diaper')) return 'Baby Care';
    if (categoryStr.includes('pet') || categoryStr.includes('animal') || categoryStr.includes('dog') || categoryStr.includes('cat')) return 'Pet Care';
    if (categoryStr.includes('electronic') || categoryStr.includes('battery') || categoryStr.includes('cable')) return 'Electronics';
    if (categoryStr.includes('office') || categoryStr.includes('stationery') || categoryStr.includes('pen')) return 'Office Supplies';
    if (categoryStr.includes('tool') || categoryStr.includes('hardware')) return 'Hardware';
    
    // Try to extract from categories_tags if available
    if (categoriesTags && categoriesTags.length > 0) {
      const mainCategory = categoriesTags[0].replace(/^[a-z]{2}:/, '').replace(/-/g, ' ');
      return this.capitalizeWords(mainCategory);
    }

    return 'Uncategorized';
  }

  /**
   * Cache management for faster searches
   */
  private addToCache(barcode: string, result: ProductSearchResult) {
    this.productCache.set(barcode, {
      ...result,
      cachedAt: Date.now()
    });
  }

  private getFromCache(barcode: string): ProductSearchResult | null {
    const cached = this.productCache.get(barcode);
    if (cached && (Date.now() - cached.cachedAt) < this.cacheTimeout) {
      const { cachedAt, ...result } = cached;
      return result;
    }
    this.productCache.delete(barcode); // Remove expired cache
    return null;
  }

  /**
   * Clear cache (useful when products are updated)
   */
  clearCache() {
    this.productCache.clear();
    this.searchIndex.clear();
  }

  /**
   * Build search index for fast local searching
   */
  private buildSearchIndex(products: Product[]) {
    this.searchIndex.clear();
    
    products.forEach(product => {
      // Index by name words
      const nameWords = product.name.toLowerCase().split(/\s+/);
      nameWords.forEach(word => {
        if (word.length > 2) { // Only index words longer than 2 characters
          if (!this.searchIndex.has(word)) {
            this.searchIndex.set(word, []);
          }
          this.searchIndex.get(word)!.push(product);
        }
      });

      // Index by barcode
      if (product.barcode) {
        this.searchIndex.set(product.barcode.toLowerCase(), [product]);
      }

      // Index by brand
      if (product.brand) {
        const brandKey = product.brand.toLowerCase();
        if (!this.searchIndex.has(brandKey)) {
          this.searchIndex.set(brandKey, []);
        }
        this.searchIndex.get(brandKey)!.push(product);
      }

      // Index by category
      const categoryKey = product.category.toLowerCase();
      if (!this.searchIndex.has(categoryKey)) {
        this.searchIndex.set(categoryKey, []);
      }
      this.searchIndex.get(categoryKey)!.push(product);
    });
  }

  /**
   * Fast search within local products using pre-built index
   */
  searchLocalProducts(products: Product[], searchTerm: string): Product[] {
    if (!searchTerm || searchTerm.length < 2) {
      return products;
    }

    const term = searchTerm.toLowerCase().trim();
    
    // Rebuild index if needed
    if (this.searchIndex.size === 0) {
      this.buildSearchIndex(products);
    }

    // Exact matches first (fastest)
    if (this.searchIndex.has(term)) {
      return this.searchIndex.get(term)!;
    }

    // Partial matches using index
    const results = new Set<Product>();
    for (const [key, indexedProducts] of this.searchIndex) {
      if (key.includes(term)) {
        indexedProducts.forEach(product => results.add(product));
      }
    }

    // Fallback to traditional search if index doesn't have enough results
    if (results.size === 0) {
      return products.filter(product =>
        product.name.toLowerCase().includes(term) ||
        product.barcode.toLowerCase().includes(term) ||
        product.category.toLowerCase().includes(term) ||
        (product.brand && product.brand.toLowerCase().includes(term)) ||
        (product.description && product.description.toLowerCase().includes(term))
      );
    }

    return Array.from(results);
  }

  /**
   * Update existing product
   */
  /**
 * Update existing product
 */
async updateProduct(productId: string, updateData: Partial<Product>): Promise<void> {
  try {
    const productDocRef = doc(this.firestore, 'products', productId);
    
    // Ensure required fields are preserved
    const updatePayload: any = {
      ...updateData,
      updated_at: Timestamp.now()
    };
    
    await updateDoc(productDocRef, updatePayload);
    
    console.log('✅ Product updated successfully:', productId);
    
    // Clear cache to ensure fresh data
    this.clearCache();
    
  } catch (error) {
    console.error('Error updating product:', error);
    throw error;
  }
}

  /**
   * Update stock with transaction history
   */
 async updateStock(productId: string, newQuantity: number, reason: string, type: string = 'adjustment'): Promise<void> {
  try {
    const storeOwnerId = this.getCurrentStoreOwnerId();
    if (!storeOwnerId) {
      throw new Error('User not authorized to update stock');
    }

    // Get current product to calculate the change
    const productDocRef = doc(this.firestore, 'products', productId);
    const productSnap = await getDoc(productDocRef);
    
    if (!productSnap.exists()) {
      throw new Error('Product not found');
    }

    const currentProduct = productSnap.data() as Product;
    const currentStock = currentProduct.stock_quantity;
    
    // Calculate the actual change amount
    let adjustmentAmount = 0;
    switch (type) {
      case 'stock_in':
        adjustmentAmount = newQuantity - currentStock;
        break;
      case 'stock_out':
        adjustmentAmount = currentStock - newQuantity; // Negative for stock out
        break;
      case 'set':
        adjustmentAmount = newQuantity - currentStock;
        break;
      default:
        adjustmentAmount = newQuantity - currentStock;
    }

    console.log('📊 Stock Adjustment:', {
      productId,
      currentStock,
      newQuantity,
      adjustmentAmount,
      type,
      reason
    });

    // Update product stock
    await updateDoc(productDocRef, {
      stock_quantity: newQuantity,
      updated_at: Timestamp.now()
    });

    // Create stock transaction record - FIXED QUANTITY
    const transactionsRef = collection(this.firestore, 'stock_transactions');
    const transactionDocRef = doc(transactionsRef);
    
    const currentUser = this.authService.getCurrentUser();
    
    await setDoc(transactionDocRef, {
      id: transactionDocRef.id,
      product_id: productId,
      product_name: currentProduct.name, // Store product name for easier queries
      type: type,
      quantity: Math.abs(adjustmentAmount), // Store the CHANGE amount (always positive)
      change_type: adjustmentAmount >= 0 ? 'increase' : 'decrease', // Track direction
      previous_stock: currentStock,
      new_stock: newQuantity,
      reason: reason,
      user_id: currentUser?.id,
      user_name: currentUser?.full_name,
      store_owner_id: storeOwnerId,
      created_at: Timestamp.now(),
      updated_at: Timestamp.now()
    });
    
    console.log('✅ Stock updated successfully with transaction:', {
      product: currentProduct.name,
      adjustment: adjustmentAmount,
      newStock: newQuantity
    });
    
    // Clear cache to ensure fresh data
    this.clearCache();
    
  } catch (error) {
    console.error('Error updating stock:', error);
    throw error;
  }
}

  /**
   * Get product transactions
   */
async getProductTransactions(productId: string): Promise<any[]> {
  try {
    const transactionsRef = collection(this.firestore, 'stock_transactions');
    const q = query(
      transactionsRef, 
      where('product_id', '==', productId),
      orderBy('created_at', 'desc'),
      limit(10) // Limit to last 10 transactions for performance
    );
    
    const querySnapshot = await getDocs(q);
    
    const transactions = querySnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        // Convert Firestore Timestamp to Date
        created_at: data['created_at']?.toDate?.() || new Date(),
        updated_at: data['updated_at']?.toDate?.() || new Date()
      };
    });

    console.log(`📊 Loaded ${transactions.length} transactions for product:`, productId);
    return transactions;
    
  } catch (error: any) {
    console.error('Error getting transactions:', error);
    
    // If it's a "collection doesn't exist" error, return empty array
    if (error.code === 'failed-precondition' || error.code === 'not-found') {
      console.log('ℹ️ Transactions collection not created yet');
      return [];
    }
    
    return [];
  }
}
  /**
   * Delete product (soft delete)
   */
  async deleteProduct(productId: string): Promise<void> {
    try {
      const productDocRef = doc(this.firestore, 'products', productId);
      
      await updateDoc(productDocRef, {
        is_active: false,
        updated_at: Timestamp.now()
      });
      
      console.log('✅ Product deleted successfully:', productId);
      
      // Clear cache to ensure fresh data
      this.clearCache();
      
    } catch (error) {
      console.error('Error deleting product:', error);
      throw error;
    }
  }

  /**
   * Bulk search for multiple barcodes (faster for inventory counts)
   */
  async bulkSearchProducts(barcodes: string[]): Promise<Map<string, ProductSearchResult>> {
    const results = new Map<string, ProductSearchResult>();
    
    // Process in batches to avoid overwhelming the APIs
    const batchSize = 5;
    for (let i = 0; i < barcodes.length; i += batchSize) {
      const batch = barcodes.slice(i, i + batchSize);
      const batchPromises = batch.map(barcode => this.searchOrCreateProductByBarcode(barcode));
      
      const batchResults = await Promise.all(batchPromises);
      batchResults.forEach((result, index) => {
        results.set(batch[index], result);
      });

      // Small delay between batches to be respectful to APIs
      if (i + batchSize < barcodes.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    return results;
  }

  // Helper methods
  private cleanProductName(name: string): string {
    if (!name) return 'Unknown Product';
    return this.capitalizeWords(name.trim());
  }

  private cleanBrandName(brand: string): string {
    if (!brand) return 'Unknown Brand';
    return this.capitalizeWords(brand.trim().split(',')[0]);
  }

  private capitalizeWords(text: string): string {
    return text
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');
  }

// Add these methods to your ProductService class

/**
 * 🔍 DEBUG: Comprehensive product search debug
 */
private async debugProductSearch(barcode: string, storeOwnerId: string): Promise<void> {
  console.log('🔍 DEBUG: Starting comprehensive product search debug');
  
  try {
    // 1. First, let's check ALL products for this store owner to see what exists
    const productsRef = collection(this.firestore, 'products');
    const allProductsQuery = query(
      productsRef, 
      where('store_owner_id', '==', storeOwnerId),
      where('is_active', '==', true)
    );
    
    const allProductsSnapshot = await getDocs(allProductsQuery);
    console.log('📦 DEBUG: All products for store owner:', {
      totalProducts: allProductsSnapshot.size,
      products: allProductsSnapshot.docs.map(doc => ({
        id: doc.id,
        barcode: doc.data()['barcode'],
        name: doc.data()['name'],
        store_owner_id: doc.data()['store_owner_id']
      }))
    });

    // 2. Now check the specific barcode query
    const specificQuery = query(
      productsRef, 
      where('barcode', '==', barcode),
      where('store_owner_id', '==', storeOwnerId),
      where('is_active', '==', true)
    );
    
    const specificSnapshot = await getDocs(specificQuery);
    console.log('🎯 DEBUG: Specific barcode query results:', {
      barcode: barcode,
      storeOwnerId: storeOwnerId,
      resultsCount: specificSnapshot.size,
      results: specificSnapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
      }))
    });

    // 3. Check if there are any products with this barcode regardless of store owner
    const globalBarcodeQuery = query(
      productsRef, 
      where('barcode', '==', barcode),
      where('is_active', '==', true)
    );
    
    const globalSnapshot = await getDocs(globalBarcodeQuery);
    console.log('🌎 DEBUG: Global barcode search (all stores):', {
      resultsCount: globalSnapshot.size,
      results: globalSnapshot.docs.map(doc => ({
        id: doc.id,
        barcode: doc.data()['barcode'],
        name: doc.data()['name'],
        store_owner_id: doc.data()['store_owner_id']
      }))
    });

  } catch (error) {
    console.error('❌ DEBUG: Error during debug search:', error);
  }
}

/**
 * 🔍 DEBUG: Check data types and values
 */
private debugDataTypes(barcode: string, storeOwnerId: string): void {
  console.log('🔍 DEBUG: Data type analysis:', {
    barcode: {
      value: barcode,
      type: typeof barcode,
      length: barcode.length,
      trimmed: barcode.trim(),
      trimmedLength: barcode.trim().length
    },
    storeOwnerId: {
      value: storeOwnerId,
      type: typeof storeOwnerId,
      length: storeOwnerId.length
    }
  });
}
/**
 * 🔥 NEW: Normalize barcode format (handle leading zeros for UPC codes)
 */
private normalizeBarcode(barcode: string): string {
  const cleanBarcode = barcode.trim();
  
  console.log('🔧 Normalizing barcode:', {
    original: barcode,
    clean: cleanBarcode,
    length: cleanBarcode.length
  });

  // Common barcode length patterns
  if (cleanBarcode.length === 11) {
    // UPC-A format without leading zero - add it
    const normalized = '0' + cleanBarcode;
    console.log('🔧 Normalized 11-digit UPC:', normalized);
    return normalized;
  } else if (cleanBarcode.length === 12) {
    // Standard UPC-A format
    console.log('🔧 Standard 12-digit UPC:', cleanBarcode);
    return cleanBarcode;
  } else if (cleanBarcode.length === 13) {
    // EAN-13 format
    console.log('🔧 Standard 13-digit EAN:', cleanBarcode);
    return cleanBarcode;
  } else if (cleanBarcode.length === 8) {
    // EAN-8 format
    console.log('🔧 Standard 8-digit EAN:', cleanBarcode);
    return cleanBarcode;
  }
  
  // For other lengths, return as is
  console.log('🔧 Unknown format, returning as-is:', cleanBarcode);
  return cleanBarcode;
}

/**
 * 🔥 NEW: Try multiple barcode variations in search
 */
private async searchWithBarcodeVariations(barcode: string, storeOwnerId: string): Promise<Product | null> {
  const variations = [
    barcode, // Original
    this.normalizeBarcode(barcode), // Normalized
    barcode.padStart(13, '0'), // Force 13 digits
    barcode.padStart(12, '0'), // Force 12 digits
  ];

  // Remove duplicates
  const uniqueVariations = [...new Set(variations)];
  
  console.log('🔄 Searching with barcode variations:', uniqueVariations);

  for (const variation of uniqueVariations) {
    try {
      const productsRef = collection(this.firestore, 'products');
      const q = query(
        productsRef, 
        where('barcode', '==', variation),
        where('store_owner_id', '==', storeOwnerId),
        where('is_active', '==', true)
      );
      
      const querySnapshot = await getDocs(q);
      
      if (!querySnapshot.empty) {
        const doc = querySnapshot.docs[0];
        const productData = doc.data();
        
        const product = { 
          id: doc.id, 
          ...productData,
          created_at: productData['created_at'],
          updated_at: productData['updated_at']
        } as Product;

        console.log('✅ Product found with variation:', {
          variation: variation,
          product: product.name,
          storedBarcode: product.barcode
        });
        return product;
      }
    } catch (error) {
      console.log(`❌ Error searching with variation ${variation}:`, error);
    }
  }
  
  return null;
}
async getOutOfStockProducts(): Promise<Product[]> {
  const products = await this.getStoreProducts();
  return products.filter(product => product.stock_quantity === 0);
}

/**
 * 🔥 NEW: Update product stock quantity
 */
async updateProductStock(productId: string, newStockQuantity: number): Promise<void> {
  try {
    const storeOwnerId = this.getCurrentStoreOwnerId();
    if (!storeOwnerId) {
      throw new Error('User not authorized to update products');
    }

    console.log('📦 Updating product stock:', {
      productId: productId,
      newStockQuantity: newStockQuantity,
      storeOwnerId: storeOwnerId
    });

    const productDocRef = doc(this.firestore, 'products', productId);
    
    // First verify the product exists and belongs to this store
    const productSnap = await getDoc(productDocRef);
    if (!productSnap.exists()) {
      throw new Error('Product not found');
    }

    const productData = productSnap.data();
    if (productData['store_owner_id'] !== storeOwnerId) {
      throw new Error('Product does not belong to your store');
    }

    // Update the stock quantity
    await updateDoc(productDocRef, {
      stock_quantity: newStockQuantity,
      updated_at: Timestamp.now()
    });

    console.log('✅ Product stock updated successfully:', {
      productId: productId,
      oldStock: productData['stock_quantity'],
      newStock: newStockQuantity
    });

    // Clear cache to ensure fresh data
    this.clearCache();
    
  } catch (error: any) {
    console.error('❌ Error updating product stock:', error);
    throw new Error('Failed to update product stock: ' + error.message);
  }
}
  /**
   * Enhanced test barcodes including both food and non-food items
   */
  getTestBarcodes(): string[] {
    return [
      // Food items
      '049000028904', // Coca-Cola
      '028400017069', // Lays Chips
      '044000037679', // Oreo Cookies
      '041789002199', // Doritos
      '075738102056', // Pepsi
      '012000130395', // Campbell's Soup
      '051500000257', // Heinz Ketchup
      
      // Non-food items (toiletries, household)
      '060384711801', // Colgate Toothpaste
      '037000571008', // Crest Toothpaste
      '028400071408', // Tide Detergent
      '036000291430', // Dove Soap
      '041331124317', // Pantene Shampoo
      '079400451408', // Gillette Razor
      '028400011700', // Dawn Dish Soap
      '044000037679', // Always Pads
      '038000136007', // Tampax
      '074312007013', // Lysol Disinfectant
      '041130001764', // Charmin Toilet Paper
      '036000012158', // Bounty Paper Towels
      
      // Health & Wellness
      '003800013135', // Advil
      '028000116406', // Tylenol
      '036000170509'  // Centrum Vitamins
    ];
  }
}