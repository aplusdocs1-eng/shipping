export type Tenant = {
  id: string;
  slug: string;
  name: string;
  prefix: string;
  currency: string;
  locale: string;
};

export type UserRole =
  | "platform_owner"
  | "platform_admin"
  | "warehouse_manager"
  | "warehouse_staff"
  | "platform_finance"
  | "platform_support"
  | "tenant_owner"
  | "tenant_admin"
  | "branch_manager"
  | "branch_staff"
  | "tenant_finance"
  | "tenant_support"
  | "driver"
  | "customer";

export type UserProfile = {
  id: string;
  email: string;
  name: string | null;
  tenant_id?: string;
  roles: UserRole[];
};
