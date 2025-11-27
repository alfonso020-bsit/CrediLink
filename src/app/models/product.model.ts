export interface Product {
  id?: string;
  store_owner_id: string;
  barcode: string;
  name: string;
  description?: string;
  category: string;
  brand?: string;
  
  // Inventory tracking
  stock_quantity: number;
  min_stock_level: number;
  max_stock_level: number;
  
  // Pricing - per piece
  cost_price: number;
  selling_price: number;
  
  // Bulk pricing
  bulk_unit?: 'pack' | 'dozen' | 'case' | 'box';
  pieces_per_bulk: number;
  bulk_selling_price: number;
  
  // Product details
  unit_of_measure: 'piece' | 'gram' | 'kilogram' | 'liter' | 'milliliter';
  weight?: number;
  volume?: number;
  
  // Images
  image_url?: string;
  barcode_image_url?: string;
  
  // Status
  status: 'active' | 'inactive' | 'discontinued';
  
  // Timestamps
  created_at: any;
  updated_at: any;
  created_by: string; // employee_id who added the product
}

export interface ProductCategory {
  id?: string;
  store_owner_id: string;
  name: string;
  description?: string;
  parent_category?: string;
  created_at: any;
}

export interface InventoryTransaction {
  id?: string;
  product_id: string;
  store_owner_id: string;
  type: 'stock_in' | 'stock_out' | 'adjustment' | 'return';
  quantity: number;
  previous_stock: number;
  new_stock: number;
  reason: string;
  reference?: string; // sale_id, purchase_order_id, etc.
  created_by: string;
  created_at: any;
}

export interface ProductSearchResult {
  product?: Product;
  exists: boolean;
  message: string;
}