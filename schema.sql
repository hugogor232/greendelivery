-- Enable PostGIS for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==========================================
-- 1. TABLES DEFINITION
-- ==========================================

-- PROFILES (Public profile synced with auth.users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    role TEXT CHECK (role IN ('consumer', 'chef', 'courier')),
    name TEXT,
    avatar TEXT,
    bio TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    location GEOGRAPHY(POINT), -- For Chefs (Kitchen) and Couriers (Last known pos)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- PRODUCTS (Dishes)
CREATE TABLE public.products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chef_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    image_url TEXT,
    category TEXT, -- 'vegan', 'italian', etc.
    ingredients TEXT,
    allergens JSONB DEFAULT '[]'::JSONB,
    stock_quantity INT DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CART ITEMS
CREATE TABLE public.cart_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- ORDERS
CREATE TABLE public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) NOT NULL, -- Consumer
    chef_id UUID REFERENCES public.profiles(id) NOT NULL, -- Chef
    courier_id UUID REFERENCES public.profiles(id), -- Courier (nullable initially)
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'cooking', 'ready_for_pickup', 'delivering', 'delivered', 'cancelled')),
    total_price NUMERIC(10, 2) NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_location GEOGRAPHY(POINT),
    payment_intent_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);

-- ORDER ITEMS (Snapshot of products at purchase time)
CREATE TABLE public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.products(id),
    quantity INT NOT NULL,
    price_at_purchase NUMERIC(10, 2) NOT NULL
);

-- MESSAGES (Chat for orders)
CREATE TABLE public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- REVIEWS
CREATE TABLE public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) NOT NULL,
    user_id UUID REFERENCES public.profiles(id) NOT NULL, -- Reviewer
    chef_id UUID REFERENCES public.profiles(id) NOT NULL, -- Reviewed Chef
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ARTICLES (Blog)
CREATE TABLE public.articles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    excerpt TEXT,
    content TEXT,
    image_url TEXT,
    category TEXT,
    author_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 2. INDEXES (Performance & Geo)
-- ==========================================

CREATE INDEX profiles_location_idx ON public.profiles USING GIST (location);
CREATE INDEX products_chef_id_idx ON public.products(chef_id);
CREATE INDEX orders_user_id_idx ON public.orders(user_id);
CREATE INDEX orders_chef_id_idx ON public.orders(chef_id);
CREATE INDEX orders_courier_id_idx ON public.orders(courier_id);
CREATE INDEX orders_status_idx ON public.orders(status);

-- ==========================================
-- 3. TRIGGERS (Auth Sync)
-- ==========================================

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, name, avatar)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'role', 'consumer'),
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    COALESCE(new.raw_user_meta_data->>'avatar_url', '')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ==========================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;

-- PROFILES
-- Everyone can read profiles (needed for displaying chefs/couriers)
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- PRODUCTS
-- Everyone can view available products
CREATE POLICY "Products are viewable by everyone" ON public.products FOR SELECT USING (true);
-- Chefs can insert/update/delete their own products
CREATE POLICY "Chefs can manage own products" ON public.products FOR ALL USING (auth.uid() = chef_id);

-- CART ITEMS
-- Users can manage their own cart
CREATE POLICY "Users can manage own cart" ON public.cart_items FOR ALL USING (auth.uid() = user_id);

-- ORDERS
-- Consumers see their own orders
CREATE POLICY "Consumers see own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
-- Chefs see orders assigned to them
CREATE POLICY "Chefs see their orders" ON public.orders FOR SELECT USING (auth.uid() = chef_id);
-- Couriers see orders assigned to them OR orders ready for pickup (to accept them)
CREATE POLICY "Couriers see assigned or available orders" ON public.orders FOR SELECT USING (
    auth.uid() = courier_id 
    OR (status = 'ready_for_pickup' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'courier'))
);

-- Insert: Consumers create orders
CREATE POLICY "Consumers can create orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Update: 
-- Chefs can update status (cooking, ready)
-- Couriers can update status (delivering, delivered) and assign themselves
CREATE POLICY "Participants can update orders" ON public.orders FOR UPDATE USING (
    auth.uid() = chef_id 
    OR auth.uid() = courier_id 
    OR (status = 'ready_for_pickup' AND courier_id IS NULL) -- Allow courier to take order
);

-- ORDER ITEMS
-- Viewable by participants of the order
CREATE POLICY "Order items viewable by participants" ON public.order_items FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.orders 
        WHERE public.orders.id = public.order_items.order_id 
        AND (public.orders.user_id = auth.uid() OR public.orders.chef_id = auth.uid() OR public.orders.courier_id = auth.uid())
    )
);
-- Insertable by consumer at creation
CREATE POLICY "Consumers can insert order items" ON public.order_items FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.orders 
        WHERE public.orders.id = public.order_items.order_id 
        AND public.orders.user_id = auth.uid()
    )
);

-- MESSAGES
-- Visible to order participants
CREATE POLICY "Messages viewable by order participants" ON public.messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.orders 
        WHERE public.orders.id = public.messages.order_id 
        AND (public.orders.user_id = auth.uid() OR public.orders.chef_id = auth.uid() OR public.orders.courier_id = auth.uid())
    )
);
-- Insertable by participants
CREATE POLICY "Messages insertable by participants" ON public.messages FOR INSERT WITH CHECK (
    auth.uid() = sender_id
);

-- REVIEWS
CREATE POLICY "Reviews viewable by everyone" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Consumers can create reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ARTICLES
CREATE POLICY "Articles viewable by everyone" ON public.articles FOR SELECT USING (true);

-- ==========================================
-- 5. FUNCTIONS (RPC)
-- ==========================================

-- Get Nearby Dishes (Geo Query)
-- Returns products sorted by distance from user
CREATE OR REPLACE FUNCTION get_nearby_dishes(lat FLOAT, long FLOAT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    price NUMERIC,
    image_url TEXT,
    category TEXT,
    description TEXT,
    chef_id UUID,
    chef_name TEXT,
    chef_avatar TEXT,
    dist_meters FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.price,
        p.image_url,
        p.category,
        p.description,
        p.chef_id,
        prof.name as chef_name,
        prof.avatar as chef_avatar,
        ST_Distance(prof.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography) as dist_meters
    FROM public.products p
    JOIN public.profiles prof ON p.chef_id = prof.id
    WHERE p.is_available = true
    ORDER BY dist_meters ASC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Get Available Orders Nearby (For Couriers)
CREATE OR REPLACE FUNCTION get_available_orders_nearby(courier_lat FLOAT, courier_long FLOAT, radius_meters FLOAT DEFAULT 5000)
RETURNS TABLE (
    id UUID,
    status TEXT,
    total_price NUMERIC,
    created_at TIMESTAMPTZ,
    chef_id UUID,
    chef_name TEXT,
    chef_address TEXT,
    dist_meters FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.status,
        o.total_price,
        o.created_at,
        o.chef_id,
        prof.name as chef_name,
        prof.address as chef_address,
        ST_Distance(prof.location, ST_SetSRID(ST_MakePoint(courier_long, courier_lat), 4326)::geography) as dist_meters
    FROM public.orders o
    JOIN public.profiles prof ON o.chef_id = prof.id
    WHERE o.status = 'ready_for_pickup'
    AND o.courier_id IS NULL
    AND ST_DWithin(prof.location, ST_SetSRID(ST_MakePoint(courier_long, courier_lat), 4326)::geography, radius_meters)
    ORDER BY dist_meters ASC;
END;
$$ LANGUAGE plpgsql;

-- Get Chef Stats
CREATE OR REPLACE FUNCTION get_chef_stats(chef_uuid UUID)
RETURNS TABLE (
    revenue NUMERIC,
    pending_count BIGINT,
    completed_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_price) FILTER (WHERE status = 'delivered'), 0) as revenue,
        COUNT(*) FILTER (WHERE status IN ('pending', 'cooking')) as pending_count,
        COUNT(*) FILTER (WHERE status = 'delivered') as completed_count
    FROM public.orders
    WHERE chef_id = chef_uuid;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 6. REALTIME
-- ==========================================

-- Enable Realtime for specific tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products; -- To update stock live