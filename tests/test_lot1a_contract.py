from __future__ import annotations

import re
import unittest
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"


def sql(name: str) -> str:
    return (MIGRATIONS / name).read_text(encoding="utf-8")


class Lot1ASchemaContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tenant_sql = sql("20261025000100_create_tenants_and_memberships.sql")
        cls.product_sql = sql("20261025000200_create_products.sql")
        cls.lot_sql = sql("20261025000300_create_product_lots.sql")
        cls.movement_sql = sql("20261025000400_create_stock_movements.sql")
        cls.all_sql = "\n".join(
            [cls.tenant_sql, cls.product_sql, cls.lot_sql, cls.movement_sql]
        ).lower()

    def test_expected_tables_only(self) -> None:
        tables = re.findall(r"create table public\.([a-z_]+)", self.all_sql)
        self.assertEqual(
            tables,
            ["tenants", "tenant_memberships", "products", "product_lots", "stock_movements"],
        )
        for forbidden in ("clients", "sessions", "session_lot_usage", "photos", "documents"):
            self.assertNotIn(f"create table public.{forbidden}", self.all_sql)

    def test_rls_enabled_on_every_table(self) -> None:
        for table in ("tenants", "tenant_memberships", "products", "product_lots", "stock_movements"):
            self.assertIn(f"alter table public.{table} enable row level security", self.all_sql)

    def test_anon_never_receives_business_table_grants(self) -> None:
        self.assertNotRegex(self.all_sql, r"grant\s+(?:select|insert|update|delete).*\bto\s+anon\b")

    def test_cross_tenant_foreign_keys_are_composite(self) -> None:
        self.assertIn("foreign key (tenant_id, product_id)", self.lot_sql.lower())
        self.assertIn("references public.products(tenant_id, id)", self.lot_sql.lower())
        self.assertIn("foreign key (tenant_id, product_lot_id)", self.movement_sql.lower())
        self.assertIn("references public.product_lots(tenant_id, id)", self.movement_sql.lower())

    def test_stock_history_is_append_only_for_authenticated(self) -> None:
        lower = self.movement_sql.lower()
        self.assertIn("grant select on public.stock_movements to authenticated", lower)
        self.assertIn("grant insert (tenant_id, product_lot_id, movement_type, quantity_delta, reason)", lower)
        self.assertNotIn("grant update", lower)
        self.assertNotIn("grant delete", lower)
        self.assertIn("stock movements are immutable", lower)

    def test_current_stock_view_is_security_invoker(self) -> None:
        lower = self.movement_sql.lower()
        self.assertIn("view public.product_lot_stock", lower)
        self.assertIn("with (security_invoker = true)", lower)
        self.assertIn("sum(movement.quantity_delta)", lower)

    def test_initial_movement_is_system_generated(self) -> None:
        lower = self.movement_sql.lower()
        self.assertIn("movement_type <> 'initial'", lower)
        self.assertIn("create_initial_stock_movement", lower)
        self.assertIn("stock_movements_one_initial_per_lot_idx", lower)


    def test_membership_bootstrap_is_database_controlled(self) -> None:
        lower = self.tenant_sql.lower()
        self.assertIn("create_creator_membership", lower)
        self.assertNotRegex(lower, r"grant\s+insert.*tenant_memberships.*to\s+authenticated")

    def test_product_unit_is_immutable_after_creation(self) -> None:
        lower = self.product_sql.lower()
        update_grant = re.search(r"grant update \(([^)]+)\)\s+on public\.products", lower, re.S)
        self.assertIsNotNone(update_grant)
        self.assertNotIn("unit", update_grant.group(1))

    def test_no_domain_specific_hardcode(self) -> None:
        for forbidden in ("pmu", "lpg", "pigment", "aiguille", "needle", "sourcil"):
            self.assertIsNone(re.search(rf"\b{re.escape(forbidden)}\b", self.all_sql))


class StockArithmeticTests(unittest.TestCase):
    def test_reference_scenario(self) -> None:
        movements = [Decimal("10"), Decimal("5"), Decimal("-3"), Decimal("-1"), Decimal("0.5")]
        self.assertEqual(sum(movements), Decimal("11.5"))

    def test_negative_guard_reference_scenario(self) -> None:
        current = Decimal("11.5")
        requested = Decimal("-12")
        self.assertLess(current + requested, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
