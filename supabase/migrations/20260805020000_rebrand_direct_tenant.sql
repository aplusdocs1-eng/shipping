-- ═══════════════════════════════════════════════════════════════
-- Rebrand the direct-tenant row from "Applizone Central Jamaica" to
-- "One Village Shipping & Freight" (matches lib/services/tenant_service.dart
-- _directCompanyName / _directTrackingPrefix). The service auth account
-- (direct@applizonecentralja.com) stays as-is — it's just the FK anchor,
-- nobody logs in through it.
-- ═══════════════════════════════════════════════════════════════

UPDATE partner_accounts
SET
  company_name = 'One Village Shipping & Freight',
  contact_name = 'One Village Shipping & Freight',
  tracking_prefix = 'OVS-'
WHERE id = '00000000-0000-0000-0000-000000000001';

UPDATE shipping_partners
SET
  code = 'OVS',
  name = 'One Village Shipping & Freight',
  tracking_prefix = 'OVS-'
WHERE id = '00000000-0000-0000-0000-000000000002';
