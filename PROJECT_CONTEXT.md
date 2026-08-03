# 🛍️ ADOT App - Complete Project Context & Architecture

## 📌 Project Overview
- **App Name:** ADOT (আদত) - Organic & Retail POS/Inventory Management App
- **Tech Stack:** Flutter (Dart), Supabase (PostgreSQL Backend)
- **Primary Data Source:** `public.products` table in Supabase
- **App Launcher Icon:** Custom "আদত" logo set at `assets/icon/app_icon.png` using `flutter_launcher_icons`.

---

## 🗄️ Database & Schema Specifications (`public.products`)
The app operates with 111+ pre-seeded product records and communicates with Supabase using the following mapped schema:

| Column Name | Data Type | Description / Usage |
| :--- | :--- | :--- |
| `id` | `bigint` | Primary Key identifier |
| `name` | `text` | Product name (e.g., "আতর", "পাবনার গাওয়া ঘি") |
| `category` | `text` | Category filtering (e.g., 'নিত্যপণ্য', 'তেল', 'ঘি', 'মধু', 'সুপার ফুড', 'খেজুর', 'সিজনাল', 'প্রসাধনী') |
| `buying_price` | `numeric(12,2)` | Base cost/buying price per unit |
| `selling_price` | `numeric(12,2)` | Base retail selling price per unit |
| `stock_quantity` | `integer` | Available main inventory count |
| `base_unit` | `text` | Flexible universal unit selection ('পিস', 'কেজি', 'গ্রাম', 'লিটার', 'এমএল', 'প্যাক') |
| `base_unit_price` | `numeric(12,2)` | Unit price fallback |
| `stock_in_base_unit` | `numeric(12,2)` | Fluid/weight-based stock tracking |
| `supplier` | `text` | Supplier brand name (Default: `ADOT Organic`) |
| `variants` | `jsonb` | Array of product variants (size_label, price, stock) |
| `image_url` | `text` | Remote/Asset product image path |
| `created_at` / `updated_at` | `timestamptz` | Automated timestamps |

---

## 🏗️ Core Architecture & Key Fixes Applied

### 1. Product Model & Price Parsing (`product_model.dart`)
- **Direct Database Fallback:** `Product.fromMap()` reads directly from `buying_price`, `selling_price`, and `stock_quantity` first.
- **Variant Guard:** Prevents zero-price (`৳0`) bugs by treating empty/null `variants` gracefully without overriding core table prices.

### 2. Supabase Payload Sanitization (`supabase_service.dart`)
- **Explicit Payload Maps:** `updateProduct()` passes ONLY valid columns defined in the Supabase schema to eliminate PostgrestException (`PGRST204` unmapped column errors).

### 3. Real-Time UI Sync across Screens
- **Refresh Notification:** Uses custom state signals (`RefreshSignal().notifyDataChanged()`) to instantly re-sync product list changes between `ProductsScreen`, Edit Dialogs, and `POSScreen`.

---

## 🚀 How to Resume Future Development

1. Open the project root in IDE.
2. Run `flutter pub get` in the terminal to restore dependencies.
3. Inform the Agent in chat:
   > *"I am resuming work on the ADOT app. Please read `PROJECT_CONTEXT.md` to understand the app architecture, Supabase schema, and data models before making changes."*