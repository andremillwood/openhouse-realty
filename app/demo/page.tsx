import { DemoWorkspace } from "@/components/demo/demo-workspace";
import { roles, type DemoRole } from "@/lib/demo/model";
export const metadata = {
  title: "Explore the demo | Open House Realty",
  robots: { index: false, follow: false },
};
export default async function DemoPage({
  searchParams,
}: {
  searchParams: Promise<{ role?: string }>;
}) {
  const { role } = await searchParams;
  const initialRole = roles.some((r) => r.id === role)
    ? (role as DemoRole)
    : undefined;
  return <DemoWorkspace initialRole={initialRole} />;
}
