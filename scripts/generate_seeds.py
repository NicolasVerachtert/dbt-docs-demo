# /// script
# requires-python = ">=3.11"
# dependencies = ["faker==37.8.0"]
# ///
"""Generate the raw seed files of the jaffle_shop demo project.

Run from the repository root:

    uv run scripts/generate_seeds.py

The script writes the raw_*.csv files in jaffle_shop/seeds/. It does not change
the reference seeds (au_states.csv, payment_methods.csv). The team maintains
these files manually.

The output is deterministic. The same SEED gives the same files.

Deliberate data issues (the staging layer and the tests show them):
- raw_customers.state has different spellings ('NSW', 'nsw', 'New South Wales').
- raw_customers.state is empty for some customers who signed up before 2024-04-01.
  The web shop did not require the state before that date.
- raw_customers.email has upper-case letters and spaces for some customers.
- raw_customers.phone has different formats.
- raw_marketing_spend.channel has display names, not channel codes.
- raw_payments contains failed payment attempts.
- Amounts in raw_orders, raw_order_items, raw_payments and raw_refunds are in cents.
"""

import csv
import math
import random
from datetime import date, datetime, timedelta
from pathlib import Path

from faker import Faker

SEED = 42
N_CUSTOMERS = 2_500
START_DATE = date(2024, 1, 1)
AS_OF_DATE = date(2026, 9, 30)  # The date of the last extract.
STATE_REQUIRED_FROM = date(2024, 4, 1)

OUT_DIR = Path(__file__).resolve().parent.parent / "jaffle_shop" / "seeds"

# ── Reference values ─────────────────────────────────────────────────────────
STATES = {
    # code: (weight, raw spellings, cities, postcode range)
    "NSW": (31, ["NSW", "nsw", "New South Wales", " NSW"], ["Sydney", "Newcastle", "Wollongong", "Parramatta"], (2000, 2599)),
    "VIC": (26, ["VIC", "Vic", "Victoria"], ["Melbourne", "Geelong", "Ballarat", "Bendigo"], (3000, 3999)),
    "QLD": (20, ["QLD", "Qld", "Queensland"], ["Brisbane", "Gold Coast", "Townsville", "Cairns"], (4000, 4999)),
    "WA": (11, ["WA", "wa", "Western Australia"], ["Perth", "Fremantle", "Bunbury"], (6000, 6797)),
    "SA": (7, ["SA", "South Australia"], ["Adelaide", "Mount Gambier"], (5000, 5799)),
    "TAS": (2, ["TAS", "Tasmania"], ["Hobart", "Launceston"], (7000, 7799)),
    "ACT": (2, ["ACT"], ["Canberra"], (2600, 2618)),
    "NT": (1, ["NT"], ["Darwin", "Alice Springs"], (800, 899)),
}

CHANNELS = {
    # code: (weight, display name in the marketing spreadsheet, target CAC in AUD)
    "organic_search": (24, None, None),
    "paid_search": (22, "Paid Search", 32.0),
    "paid_social": (19, "Paid social", 41.0),
    "affiliate": (9, "Affiliate", 18.0),
    "referral": (10, "Referral", 10.0),
    "direct": (16, None, None),
}

PAYMENT_METHODS = ["credit_card", "debit_card", "digital_wallet", "buy_now_pay_later", "gift_card"]
PAYMENT_WEIGHTS = [45, 20, 20, 10, 5]

REFUND_REASONS = ["changed_mind", "damaged_item", "wrong_item", "late_delivery"]

# Products: (sku, name, category, price in cents, cost in cents, weight, is_active)
PRODUCTS = [
    ("KIT-001", "Classic Jaffle Iron", "kitchenware", 3995, 1650, 4, True),
    ("KIT-002", "Double Jaffle Iron", "kitchenware", 5495, 2300, 3, True),
    ("KIT-003", "Electric Jaffle Maker", "kitchenware", 8995, 4100, 3, True),
    ("KIT-004", "Cast Iron Jaffle Iron", "kitchenware", 6995, 3050, 2, True),
    ("KIT-005", "Campfire Jaffle Iron", "kitchenware", 4495, 1900, 2, True),
    ("KIT-006", "Jaffle Iron Cleaning Brush", "kitchenware", 1295, 380, 3, True),
    ("KIT-007", "Bread Knife", "kitchenware", 3495, 1400, 2, True),
    ("KIT-008", "Jaffle Iron Gift Set", "kitchenware", 11995, 5600, 1, True),
    ("KIT-009", "Mini Jaffle Iron", "kitchenware", 2995, 1300, 2, False),
    ("PAN-001", "White Sandwich Loaf", "pantry", 650, 260, 10, True),
    ("PAN-002", "Sourdough Loaf", "pantry", 895, 380, 9, True),
    ("PAN-003", "Gluten-free Loaf", "pantry", 1095, 520, 4, True),
    ("PAN-004", "Baked Beans Can", "pantry", 450, 150, 8, True),
    ("PAN-005", "Spaghetti Can", "pantry", 450, 150, 6, True),
    ("PAN-006", "Aged Cheddar Block", "pantry", 1250, 610, 8, True),
    ("PAN-007", "Ham Off the Bone", "pantry", 1495, 820, 5, True),
    ("PAN-008", "Tomato Relish", "pantry", 895, 290, 6, True),
    ("PAN-009", "Apple Pie Filling", "pantry", 795, 270, 4, True),
    ("PAN-010", "Chilli Jam", "pantry", 995, 330, 3, True),
    ("PAN-011", "Curry Mince Kit", "pantry", 1695, 780, 3, True),
    ("PAN-012", "Spiced Pear Filling", "pantry", 895, 300, 1, False),
    ("COF-001", "House Blend Coffee Beans 500 g", "coffee_and_tea", 2495, 1050, 7, True),
    ("COF-002", "Single Origin Coffee Beans 250 g", "coffee_and_tea", 1995, 880, 4, True),
    ("COF-003", "Decaf Coffee Beans 250 g", "coffee_and_tea", 1795, 790, 2, True),
    ("COF-004", "English Breakfast Tea", "coffee_and_tea", 1095, 340, 4, True),
    ("COF-005", "Chai Tea", "coffee_and_tea", 1295, 420, 3, True),
    ("COF-006", "Hot Chocolate Mix", "coffee_and_tea", 1395, 460, 4, True),
    ("MER-001", "Jaffle Shop Apron", "merchandise", 3495, 1100, 2, True),
    ("MER-002", "Jaffle Shop Mug", "merchandise", 1995, 520, 4, True),
    ("MER-003", "Jaffle Shop Tote Bag", "merchandise", 1495, 410, 3, True),
    ("MER-004", "Jaffle Shop T-shirt", "merchandise", 3995, 1250, 2, True),
    ("MER-005", "Jaffle Recipe Book", "merchandise", 2995, 980, 2, True),
    ("MER-006", "Jaffle Shop Cap", "merchandise", 2495, 820, 1, False),
    ("GFT-001", "Gift Card AUD 50", "gift_cards", 5000, 0, 1, True),
    ("GFT-002", "Gift Card AUD 100", "gift_cards", 10000, 0, 1, True),
]
# Products with a price increase on PRICE_CHANGE_DATE. raw_products has the new price.
PRICE_CHANGE_DATE = date(2025, 7, 1)
PRICE_INCREASES = {"PAN-006": 1.12, "PAN-007": 1.10, "COF-001": 1.08, "COF-002": 1.08, "KIT-003": 1.05}
# Products that are not sold any more: last sale date.
DISCONTINUED_ON = {"KIT-009": date(2025, 3, 31), "PAN-012": date(2024, 9, 30), "MER-006": date(2025, 11, 30)}

COUPONS = {
    "WELCOME10": 0.10,  # First order only.
    "WINTER15": 0.15,  # June to August.
    "BLACKFRIDAY20": 0.20,  # Last week of November.
}
FREE_SHIPPING_FROM_CENTS = 10_000
SHIPPING_FEE_CENTS = 995


# ── Helpers ───────────────────────────────────────────────────────────────────
def days_between(a: date, b: date) -> int:
    return (b - a).days


def signup_date() -> date:
    """Signups grow over time, with a peak in November and December."""
    total_days = days_between(START_DATE, AS_OF_DATE)
    while True:
        d = START_DATE + timedelta(days=random.randint(0, total_days))
        growth = 0.45 + 0.55 * days_between(START_DATE, d) / total_days
        season = 1.35 if d.month in (11, 12) else 1.0
        if random.random() < growth * season / 1.35:
            return d


def random_time(d: date) -> datetime:
    hour = random.choices(range(24), weights=[1, 1, 1, 1, 1, 2, 3, 5, 6, 6, 6, 7, 8, 7, 6, 6, 6, 7, 9, 10, 9, 7, 4, 2])[0]
    return datetime.combine(d, datetime.min.time()) + timedelta(hours=hour, minutes=random.randint(0, 59), seconds=random.randint(0, 59))


def phone_number() -> str:
    digits = "04" + "".join(str(random.randint(0, 9)) for _ in range(8))
    style = random.choices([0, 1, 2, 3], weights=[50, 25, 15, 10])[0]
    if style == 0:
        return f"{digits[:4]} {digits[4:7]} {digits[7:]}"
    if style == 1:
        return digits
    if style == 2:
        return f"+61 {digits[1:4]} {digits[4:7]} {digits[7:]}"
    return f"({digits[:2]}) {digits[2:6]} {digits[6:]}"


def write_csv(name: str, rows: list[dict]) -> None:
    path = OUT_DIR / f"{name}.csv"
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"  {path.name:<28} {len(rows):>7,} rows")


# ── Generators ────────────────────────────────────────────────────────────────
def build_products() -> list[dict]:
    rows = []
    for idx, (sku, name, category, price, cost, _, is_active) in enumerate(PRODUCTS, start=1):
        current_price = price
        if sku in PRICE_INCREASES:
            current_price = int(round(price * PRICE_INCREASES[sku] / 5) * 5)
        rows.append(
            {
                "id": idx,
                "sku": sku,
                "name": name,
                "category": category,
                "price": current_price,
                "cost": cost,
                "is_active": str(is_active).lower(),
                "launched_on": (START_DATE - timedelta(days=random.randint(30, 900))).isoformat(),
            }
        )
    return rows


def price_on(product: dict, base: tuple, d: date) -> int:
    """Return the price in cents on date d."""
    if base[0] in PRICE_INCREASES and d < PRICE_CHANGE_DATE:
        return base[3]
    return product["price"]


def build_customers(fake: Faker) -> list[dict]:
    rows = []
    used_emails: set[str] = set()
    state_codes = list(STATES)
    for idx in range(1, N_CUSTOMERS + 1):
        first, last = fake.first_name(), fake.last_name()
        signup = signup_date()
        code = random.choices(state_codes, weights=[s[0] for s in STATES.values()])[0]
        _, spellings, cities, (pc_lo, pc_hi) = STATES[code]
        raw_state = spellings[0] if random.random() < 0.8 else random.choice(spellings)
        if signup < STATE_REQUIRED_FROM and random.random() < 0.18:
            raw_state = ""

        base = f"{first}.{last}".lower().replace("'", "").replace(" ", "")
        email = f"{base}@{random.choice(['example.com', 'example.net', 'example.org'])}"
        n = 2
        while email in used_emails:
            email = f"{base}{n}@{email.split('@')[1]}"
            n += 1
        used_emails.add(email)
        roll = random.random()
        if roll < 0.04:
            email = email.title()
        elif roll < 0.06:
            email = f" {email} "

        rows.append(
            {
                "id": idx,
                "first_name": first,
                "last_name": last,
                "email": email,
                "phone": phone_number() if random.random() < 0.85 else "",
                "city": random.choice(cities),
                "state": raw_state,
                "postcode": f"{random.randint(pc_lo, pc_hi):04d}",
                "acquisition_channel": random.choices(list(CHANNELS), weights=[c[0] for c in CHANNELS.values()])[0],
                "marketing_opt_in": str(random.random() < 0.62).lower(),
                "created_at": random_time(signup).isoformat(sep=" "),
            }
        )
    # Sort on signup time so that the ID order follows the signup order.
    rows.sort(key=lambda r: r["created_at"])
    for idx, row in enumerate(rows, start=1):
        row["id"] = idx
    return rows


def order_status(order_date: date, has_returnable_items: bool) -> str:
    age = days_between(order_date, AS_OF_DATE)
    if age <= 2:
        return "placed"
    if age <= 6:
        return "shipped" if random.random() < 0.85 else "completed"
    if has_returnable_items and random.random() < 0.05:
        return "return_pending" if age <= 30 and random.random() < 0.6 else "returned"
    return "completed"


def coupon_for(order_date: date, is_first: bool) -> str:
    if is_first and random.random() < 0.30:
        return "WELCOME10"
    if order_date.month in (6, 7, 8) and random.random() < 0.10:
        return "WINTER15"
    if order_date.month == 11 and order_date.day >= 24 and random.random() < 0.45:
        return "BLACKFRIDAY20"
    return ""


def build_orders(customers: list[dict], products: list[dict]):
    orders, items, payments, refunds = [], [], [], []
    product_weights = [p[5] for p in PRODUCTS]
    order_id = item_id = payment_id = refund_id = 0

    planned = []  # (order_date, customer_id, is_first)
    for cust in customers:
        if random.random() < 0.11:
            continue  # Signed up, but never ordered.
        signup = datetime.fromisoformat(cust["created_at"]).date()
        d = signup + timedelta(days=min(int(random.expovariate(1 / 4)), 60))
        loyalty = random.choices([0.15, 0.4, 0.7, 0.85], weights=[35, 35, 20, 10])[0]
        mean_gap = random.choice([35, 60, 90, 150])
        first = True
        while d <= AS_OF_DATE:
            planned.append((d, int(cust["id"]), first))
            first = False
            if random.random() > loyalty:
                break
            d = d + timedelta(days=max(3, int(random.expovariate(1 / mean_gap))))
    planned.sort()

    for d, customer_id, is_first in planned:
        order_id += 1
        coupon = coupon_for(d, is_first)
        discount_pct = COUPONS.get(coupon, 0.0)

        n_lines = random.choices([1, 2, 3, 4, 5], weights=[30, 30, 20, 12, 8])[0]
        chosen = set()
        lines = []
        for _ in range(n_lines):
            idx = random.choices(range(len(PRODUCTS)), weights=product_weights)[0]
            base = PRODUCTS[idx]
            if idx in chosen or (base[0] in DISCONTINUED_ON and d > DISCONTINUED_ON[base[0]]):
                continue
            if base[2] == "gift_cards" and coupon:
                continue  # Coupons are not valid on gift cards.
            chosen.add(idx)
            product = products[idx]
            qty = 1 if base[2] in ("kitchenware", "gift_cards") else random.choices([1, 2, 3, 4], weights=[55, 28, 12, 5])[0]
            unit_price = price_on(product, base, d)
            discount = int(math.floor(qty * unit_price * discount_pct))
            lines.append((product, base, qty, unit_price, discount))
        if not lines:
            idx = 9  # White Sandwich Loaf: always available.
            product, base = products[idx], PRODUCTS[idx]
            unit_price = price_on(product, base, d)
            lines.append((product, base, 1, unit_price, int(math.floor(unit_price * discount_pct))))

        net_items = sum(q * up - disc for _, _, q, up, disc in lines)
        only_gift_cards = all(b[2] == "gift_cards" for _, b, *_ in lines)
        shipping = 0 if net_items >= FREE_SHIPPING_FROM_CENTS or only_gift_cards else SHIPPING_FEE_CENTS
        total = net_items + shipping
        returnable = any(b[2] in ("kitchenware", "merchandise") for _, b, *_ in lines)
        status = order_status(d, returnable)

        orders.append(
            {
                "id": order_id,
                "user_id": customer_id,
                "order_date": d.isoformat(),
                "status": status,
                "sales_channel": random.choices(["web", "app"], weights=[68, 32] if d.year >= 2025 else [85, 15])[0],
                "coupon_code": coupon,
                "shipping_fee": shipping,
            }
        )
        for product, base, qty, unit_price, discount in lines:
            item_id += 1
            items.append(
                {
                    "id": item_id,
                    "order_id": order_id,
                    "product_id": product["id"],
                    "quantity": qty,
                    "unit_price": unit_price,
                    "discount_amount": discount,
                }
            )

        # Payments. The customer pays when the order is placed.
        paid_at = random_time(d)
        if random.random() < 0.04:
            payment_id += 1
            payments.append(
                {"id": payment_id, "order_id": order_id, "payment_method": "credit_card", "status": "failed", "amount": total, "created_at": (paid_at - timedelta(minutes=random.randint(1, 9))).isoformat(sep=" ")}
            )
        method = random.choices(PAYMENT_METHODS, weights=PAYMENT_WEIGHTS)[0]
        if method == "gift_card" and not only_gift_cards:
            gift_amount = min(total, random.choice([2000, 5000, 10000]))
            payment_id += 1
            payments.append({"id": payment_id, "order_id": order_id, "payment_method": "gift_card", "status": "success", "amount": gift_amount, "created_at": paid_at.isoformat(sep=" ")})
            if total > gift_amount:
                payment_id += 1
                payments.append({"id": payment_id, "order_id": order_id, "payment_method": "credit_card", "status": "success", "amount": total - gift_amount, "created_at": paid_at.isoformat(sep=" ")})
        else:
            if method == "gift_card":
                method = "credit_card"  # Gift cards cannot pay for gift cards.
            payment_id += 1
            payments.append({"id": payment_id, "order_id": order_id, "payment_method": method, "status": "success", "amount": total, "created_at": paid_at.isoformat(sep=" ")})

        # Refunds.
        refund_amount, reason = 0, ""
        if status == "returned":
            returned = [(q * up - disc) for _, b, q, up, disc in lines if b[2] in ("kitchenware", "merchandise")]
            refund_amount = sum(returned)
            reason = random.choices(REFUND_REASONS, weights=[45, 25, 20, 10])[0]
        elif status == "completed" and random.random() < 0.015:
            q, up, disc = lines[0][2], lines[0][3], lines[0][4]
            refund_amount = (q * up - disc) // (2 if random.random() < 0.5 else 1)
            reason = random.choice(["damaged_item", "late_delivery"])
        if refund_amount > 0:
            refund_date = d + timedelta(days=random.randint(10, 28))
            if refund_date <= AS_OF_DATE:
                refund_id += 1
                refunds.append(
                    {"id": refund_id, "order_id": order_id, "amount": refund_amount, "reason": reason, "refunded_at": random_time(refund_date).isoformat(sep=" ")}
                )
            elif status == "returned":
                orders[-1]["status"] = "return_pending"

    return orders, items, payments, refunds


def build_marketing_spend(customers: list[dict]) -> list[dict]:
    """Monthly spend for each paid channel. Spend follows the number of new customers."""
    new_by_month: dict[tuple[str, str], int] = {}
    for c in customers:
        month = c["created_at"][:7]
        key = (month, c["acquisition_channel"])
        new_by_month[key] = new_by_month.get(key, 0) + 1

    rows = []
    month = START_DATE
    while month <= AS_OF_DATE:
        m = month.strftime("%Y-%m")
        for code, (_, display_name, cac) in CHANNELS.items():
            if display_name is None:
                continue
            new = new_by_month.get((m, code), 0)
            spend = new * cac * random.uniform(0.75, 1.3) + random.uniform(150, 600)
            rows.append({"month": f"{m}-01", "channel": display_name, "spend_aud": f"{spend:.2f}"})
        month = (month.replace(day=28) + timedelta(days=4)).replace(day=1)
    return rows


def main() -> None:
    random.seed(SEED)
    Faker.seed(SEED)
    fake = Faker("en_AU")

    products = build_products()
    customers = build_customers(fake)
    orders, items, payments, refunds = build_orders(customers, products)
    spend = build_marketing_spend(customers)

    print(f"Writing seeds to {OUT_DIR}")
    write_csv("raw_customers", customers)
    write_csv("raw_products", products)
    write_csv("raw_orders", orders)
    write_csv("raw_order_items", items)
    write_csv("raw_payments", payments)
    write_csv("raw_refunds", refunds)
    write_csv("raw_marketing_spend", spend)


if __name__ == "__main__":
    main()
