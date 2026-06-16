DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.governorates CASCADE;
DROP TYPE  IF EXISTS public.order_status CASCADE;
DROP TYPE  IF EXISTS public.app_role CASCADE;

CREATE TYPE public.order_status AS ENUM (
  'new','pending','processing','ready','picked_up','out_for_delivery',
  'shipped','delivered','delivered_with_modification','returned','return_no_shipping','failed',
  'postponed','cancelled','agent_deleted'
);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TABLE public.admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_admin_users_updated BEFORE UPDATE ON public.admin_users
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.admin_user_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
  permission text NOT NULL,
  permission_type text NOT NULL DEFAULT 'view',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, permission)
);

CREATE TABLE public.activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid, username text, action text NOT NULL, section text, details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.system_passwords (
  id text PRIMARY KEY, password text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.app_settings (
  id text PRIMARY KEY DEFAULT 'main',
  active_theme text NOT NULL DEFAULT 'blue-default',
  active_template text NOT NULL DEFAULT 'classic',
  platform_name text NOT NULL DEFAULT 'متجر فاشون',
  invoice_name text NOT NULL DEFAULT 'متجر فاشون',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, logo_url text, watermark_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.governorates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  shipping_cost numeric NOT NULL DEFAULT 0,
  agent_shipping_cost numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, description text, image_url text,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, description text, details text,
  price numeric NOT NULL DEFAULT 0,
  offer_price numeric, discount_price numeric,
  is_offer boolean NOT NULL DEFAULT false,
  is_featured boolean NOT NULL DEFAULT false,
  image_url text,
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  stock integer NOT NULL DEFAULT 0,
  stock_quantity integer NOT NULL DEFAULT 0,
  low_stock_threshold integer NOT NULL DEFAULT 5,
  rating numeric NOT NULL DEFAULT 0,
  reviews_count integer NOT NULL DEFAULT 0,
  size_options text[] NOT NULL DEFAULT '{}',
  color_options text[] NOT NULL DEFAULT '{}',
  quantity_pricing jsonb NOT NULL DEFAULT '[]'::jsonb,
  size_pricing jsonb NOT NULL DEFAULT '[]'::jsonb,
  name_ar text, name_en text, description_ar text, description_en text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.product_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.product_color_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
  color text, image_url text,
  stock integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL, product_id uuid, user_id uuid, metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, phone text, phone2 text, address text, governorate text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_customers_phone ON public.customers(phone);

CREATE TABLE public.delivery_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, phone text, serial_number text,
  total_owed numeric NOT NULL DEFAULT 0,
  total_paid numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS public.order_number_seq START 1000;

CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number bigint NOT NULL DEFAULT nextval('public.order_number_seq') UNIQUE,
  tracking_code text UNIQUE,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  governorate_id uuid REFERENCES public.governorates(id) ON DELETE SET NULL,
  status public.order_status NOT NULL DEFAULT 'pending',
  total_amount numeric NOT NULL DEFAULT 0,
  shipping_cost numeric NOT NULL DEFAULT 0,
  agent_shipping_cost numeric NOT NULL DEFAULT 0,
  discount numeric NOT NULL DEFAULT 0,
  modified_amount numeric NOT NULL DEFAULT 0,
  order_details text, notes text,
  assigned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_agent ON public.orders(delivery_agent_id);
CREATE INDEX idx_orders_customer ON public.orders(customer_id);
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.set_order_tracking_code()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.tracking_code IS NULL OR NEW.tracking_code = '' THEN
    NEW.tracking_code := 'TRK-' || lpad(NEW.order_number::text, 6, '0');
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_orders_tracking BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.set_order_tracking_code();

CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  quantity integer NOT NULL DEFAULT 1,
  price numeric NOT NULL DEFAULT 0,
  size text, color text, product_details text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_order_items_order ON public.order_items(order_id);

CREATE TABLE public.returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  return_amount numeric NOT NULL DEFAULT 0,
  shipping_deduction numeric NOT NULL DEFAULT 0,
  returned_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_returns_order ON public.returns(order_id);

CREATE TABLE public.agent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  amount numeric NOT NULL DEFAULT 0,
  payment_type text NOT NULL DEFAULT 'payment',
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_agent_payments_agent ON public.agent_payments(delivery_agent_id);
CREATE INDEX idx_agent_payments_order ON public.agent_payments(order_id);

CREATE TABLE public.agent_daily_closings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE CASCADE,
  closing_date date NOT NULL,
  net_amount numeric NOT NULL DEFAULT 0,
  closed_by uuid, closed_by_username text, notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(delivery_agent_id, closing_date)
);

CREATE TABLE public.cashbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  opening_balance numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cashbox_id uuid REFERENCES public.cashbox(id) ON DELETE CASCADE,
  type text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  reason text, description text,
  payment_method text DEFAULT 'cash',
  user_id uuid, username text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_cashbox_tx_cashbox ON public.cashbox_transactions(cashbox_id);

CREATE TABLE public.treasury (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  description text, category text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.statistics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric text, value numeric NOT NULL DEFAULT 0,
  total_sales numeric NOT NULL DEFAULT 0,
  total_orders integer NOT NULL DEFAULT 0,
  last_reset timestamptz, metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.scan_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid, username text,
  status text NOT NULL DEFAULT 'active',
  total_scanned integer NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz
);

CREATE TABLE public.scan_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES public.scan_sessions(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  scanned_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.scan_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid, username text,
  session_id uuid REFERENCES public.scan_sessions(id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  action text NOT NULL, old_value text, new_value text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  old_status text, new_status text NOT NULL,
  changed_by uuid, changed_by_username text, source text, notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Business logic triggers
CREATE OR REPLACE FUNCTION public.apply_governorate_agent_shipping()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE gov_cost numeric;
BEGIN
  IF NEW.governorate_id IS NULL THEN RETURN NEW; END IF;
  IF COALESCE(NEW.agent_shipping_cost, 0) = 0 THEN
    SELECT COALESCE(agent_shipping_cost, 0) INTO gov_cost
    FROM public.governorates WHERE id = NEW.governorate_id;
    IF gov_cost IS NOT NULL AND gov_cost > 0 THEN
      NEW.agent_shipping_cost := gov_cost;
    END IF;
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER apply_governorate_agent_shipping_trg
BEFORE INSERT OR UPDATE OF governorate_id, agent_shipping_cost ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.apply_governorate_agent_shipping();

CREATE OR REPLACE FUNCTION public.log_order_status_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.order_status_history (order_id, old_status, new_status)
    VALUES (NEW.id, OLD.status::text, NEW.status::text);
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_log_order_status_change AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.log_order_status_change();

CREATE OR REPLACE FUNCTION public.handle_order_agent_assignment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE final_agent_shipping numeric; accounting_date date;
BEGIN
  IF NEW.delivery_agent_id IS NOT NULL AND OLD.delivery_agent_id IS NULL THEN
    NEW.assigned_at := now();
    final_agent_shipping := COALESCE(NEW.agent_shipping_cost, 0);
    accounting_date := DATE(COALESCE(NEW.assigned_at, now()) AT TIME ZONE 'Africa/Cairo');
    INSERT INTO public.agent_payments (delivery_agent_id, order_id, amount, payment_type, payment_date, notes)
    VALUES (NEW.delivery_agent_id, NEW.id,
            NEW.total_amount + COALESCE(NEW.shipping_cost,0) - final_agent_shipping,
            'owed', accounting_date,
            'تعيين طلب رقم ' || COALESCE(NEW.order_number::text, NEW.id::text));
    UPDATE public.delivery_agents
    SET total_owed = COALESCE(total_owed,0) + NEW.total_amount + COALESCE(NEW.shipping_cost,0) - final_agent_shipping
    WHERE id = NEW.delivery_agent_id;
    NEW.status := 'shipped';
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_order_agent_assignment BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.handle_order_agent_assignment();

CREATE OR REPLACE FUNCTION public.clear_agent_on_revert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE order_amount numeric;
BEGIN
  IF OLD.delivery_agent_id IS NOT NULL
     AND NEW.status IN ('pending','processing')
     AND OLD.status NOT IN ('pending','processing') THEN
    order_amount := NEW.total_amount + COALESCE(NEW.shipping_cost,0) - COALESCE(NEW.agent_shipping_cost,0);
    DELETE FROM public.agent_payments
    WHERE order_id = NEW.id AND delivery_agent_id = OLD.delivery_agent_id
      AND payment_type IN ('owed','delivered');
    UPDATE public.delivery_agents SET total_owed = COALESCE(total_owed,0) - order_amount
    WHERE id = OLD.delivery_agent_id;
    NEW.delivery_agent_id := NULL;
    NEW.assigned_at := NULL;
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_clear_agent_on_revert BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.clear_agent_on_revert();

CREATE OR REPLACE FUNCTION public.handle_return_creation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE accounting_date date; order_assigned_at timestamptz;
BEGIN
  IF NEW.delivery_agent_id IS NOT NULL THEN
    UPDATE public.delivery_agents SET total_owed = total_owed - NEW.return_amount
    WHERE id = NEW.delivery_agent_id;
    SELECT o.assigned_at INTO order_assigned_at FROM public.orders o WHERE o.id = NEW.order_id;
    accounting_date := DATE(COALESCE(order_assigned_at, now()) AT TIME ZONE 'Africa/Cairo');
    INSERT INTO public.agent_payments (delivery_agent_id, order_id, amount, payment_type, payment_date, notes)
    VALUES (NEW.delivery_agent_id, NEW.order_id, -NEW.return_amount, 'return', accounting_date,
            'مرتجع - طلب رقم ' || NEW.order_id);
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_return_created AFTER INSERT ON public.returns
FOR EACH ROW EXECUTE FUNCTION public.handle_return_creation();

CREATE OR REPLACE FUNCTION public.delete_old_activity_logs()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM public.activity_logs WHERE created_at < now() - interval '3 days';
$$;

CREATE OR REPLACE FUNCTION public.reset_order_sequence()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN PERFORM setval('public.order_number_seq', 1000, false); END;
$$;

-- RLS + GRANTS for all tables
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'admin_users','admin_user_permissions','activity_logs','system_passwords',
    'app_settings','offices','governorates','categories',
    'products','product_images','product_color_variants','analytics_events',
    'customers','delivery_agents',
    'orders','order_items','returns',
    'agent_payments','agent_daily_closings',
    'cashbox','cashbox_transactions','treasury','statistics',
    'scan_sessions','scan_session_items','scan_logs','order_status_history'
  ])
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY "public_all" ON public.%I FOR ALL USING (true) WITH CHECK (true)', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
  END LOOP;
END $$;

GRANT USAGE, SELECT ON SEQUENCE public.order_number_seq TO anon, authenticated, service_role;

-- Realtime
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.scan_session_items REPLICA IDENTITY FULL;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.scan_session_items;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed data
INSERT INTO public.app_settings (id, platform_name, invoice_name)
VALUES ('main', 'متجر فاشون', 'متجر فاشون')
ON CONFLICT (id) DO UPDATE SET platform_name = EXCLUDED.platform_name, invoice_name = EXCLUDED.invoice_name;

INSERT INTO public.system_passwords (id, password) VALUES
  ('admin_delete',      '01278006248'),
  ('treasury_password', '01278006248'),
  ('vault_password',    '01278006248'),
  ('master_password',   '01278006248')
ON CONFLICT (id) DO UPDATE SET password = EXCLUDED.password, updated_at = now();

WITH owner_user AS (
  INSERT INTO public.admin_users (username, password, is_active)
  VALUES ('المالك', '01278006248', true)
  RETURNING id
)
INSERT INTO public.admin_user_permissions (user_id, permission, permission_type)
SELECT owner_user.id, p, 'edit'
FROM owner_user,
     unnest(ARRAY[
       'orders','products','categories','customers','agents','agent_orders',
       'agent_payments','governorates','statistics','invoices','all_orders',
       'settings','reset_data','user_management','cashbox','treasury',
       'barcode_scanner'
     ]) AS p;

INSERT INTO public.governorates (name, shipping_cost) VALUES
  ('القاهرة', 60),('الجيزة', 60),('الإسكندرية', 70),('الدقهلية', 70),
  ('الشرقية', 70),('القليوبية', 60),('المنوفية', 70),('الغربية', 70),
  ('البحيرة', 80),('الإسماعيلية', 80),('كفر الشيخ', 80),('دمياط', 80),
  ('بورسعيد', 80),('السويس', 80),('الفيوم', 80),('بني سويف', 80),
  ('المنيا', 90),('أسيوط', 90),('سوهاج', 100),('قنا', 100),
  ('أسوان', 110),('الأقصر', 110),('البحر الأحمر', 120),
  ('الوادي الجديد', 130),('مطروح', 130),('شمال سيناء', 130),('جنوب سيناء', 130);