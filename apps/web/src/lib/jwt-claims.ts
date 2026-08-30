// Custom JWT claims injected by the `custom_access_token` Postgres Auth Hook.
// Shape matches docs/engida-hms-master-blueprint-v1.md §5.4.
export interface EngidaJwtClaims {
  tenant_id: string | null;
  property_ids: string[];
  roles: string[];
  plan: "starter" | "growth" | "pro" | null;
  tenant_status: "trial" | "active" | "past_due" | "suspended" | "cancelled" | null;
  imp?: { by: string; exp: number };
}

function base64UrlDecode(input: string): string {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/").padEnd(input.length + ((4 - (input.length % 4)) % 4), "=");
  return atob(padded);
}

/** Decodes claims from a Supabase access token without verifying the signature
 * (verification happens server-side on every RPC/RLS check — this is UI-only). */
export function decodeJwtClaims(accessToken: string): EngidaJwtClaims | null {
  const parts = accessToken.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(base64UrlDecode(parts[1]));
    return {
      tenant_id: payload.tenant_id ?? null,
      property_ids: payload.property_ids ?? [],
      roles: payload.roles ?? [],
      plan: payload.plan ?? null,
      tenant_status: payload.tenant_status ?? null,
      imp: payload.imp,
    };
  } catch {
    return null;
  }
}
