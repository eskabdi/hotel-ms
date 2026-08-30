import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { decodeJwtClaims, type EngidaJwtClaims } from "./jwt-claims";

interface SessionContextValue {
  session: Session | null;
  claims: EngidaJwtClaims | null;
  loading: boolean;
  hasRole: (role: string) => boolean;
}

const SessionContext = createContext<SessionContextValue | undefined>(undefined);

// Single source of session truth (§5.3) — the router guard and every
// permission check reads from this provider, never from localStorage directly.
export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => subscription.unsubscribe();
  }, []);

  const claims = session ? decodeJwtClaims(session.access_token) : null;

  const hasRole = (role: string) => claims?.roles.includes(role) ?? false;

  return (
    <SessionContext.Provider value={{ session, claims, loading, hasRole }}>
      {children}
    </SessionContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components -- colocated with its provider by design
export function useSession(): SessionContextValue {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession must be used within SessionProvider");
  return ctx;
}
