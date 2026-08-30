import { useTranslation } from "react-i18next";
import { useSession } from "@/lib/session-provider";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function DashboardPage() {
  const { t } = useTranslation();
  const { claims } = useSession();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold text-text-primary">{t("nav.dashboard")}</h1>
      <Card className="max-w-md">
        <CardHeader>
          <CardTitle>Session claims</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-text-secondary">
          <p>tenant_id: {claims?.tenant_id ?? "—"}</p>
          <p>roles: {claims?.roles.join(", ") || "—"}</p>
          <p>property_ids: {claims?.property_ids.join(", ") || "—"}</p>
          <p>tenant_status: {claims?.tenant_status ?? "—"}</p>
        </CardContent>
      </Card>
    </div>
  );
}
