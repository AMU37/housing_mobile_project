/** يحوّل مسار التطبيق إلى مسار ملف ثابت (static export) في الإنتاج. */
export function routePath(path: string): string {
  if (!path.startsWith("/")) return path;
  if (process.env.NODE_ENV === "development") return path;
  const q = path.indexOf("?");
  const base = q === -1 ? path : path.slice(0, q);
  const query = q === -1 ? "" : path.slice(q);
  if (base === "/" || base.endsWith(".html")) return path;
  return `${base}/index.html${query}`;
}

/** الصفحة الرئيسية المناسبة لكل دور بعد تسجيل الدخول. */
export function homeForRole(user: { permissions?: string[]; roleId?: string | null; role?: string } | null | undefined): string {
  if (!user) return "/";
  const permissions = new Set(user.permissions || []);
  if (permissions.has("contractor.portal") && !permissions.has("dashboard.view")) return "/contractor";
  if (permissions.has("dashboard.view")) return "/dashboard";
  if (permissions.has("operations.view")) return "/operations";
  if (permissions.has("housing.view")) return "/housing";
  if (permissions.has("residents.view")) return "/residents";
  if (permissions.has("reports.view")) return "/reports";
  return "/about";
}
