
DROP POLICY IF EXISTS "products_select" ON storage.objects;
DROP POLICY IF EXISTS "products_insert" ON storage.objects;
DROP POLICY IF EXISTS "products_update" ON storage.objects;
DROP POLICY IF EXISTS "products_delete" ON storage.objects;

CREATE POLICY "products_select" ON storage.objects FOR SELECT USING (bucket_id = 'products');
CREATE POLICY "products_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'products');
CREATE POLICY "products_update" ON storage.objects FOR UPDATE USING (bucket_id = 'products');
CREATE POLICY "products_delete" ON storage.objects FOR DELETE USING (bucket_id = 'products');
