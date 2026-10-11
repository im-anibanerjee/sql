"""
FinanceTrackerDB - Piece 12 companion diagram: how a CHAINED inner join
actually works, row by row.

Every join diagram so far (the course's own "02 sql joins.md" infographics,
and this project's own populated-schema diagram) showed a two-table join.
Piece 12 is the first query in this project that chains THREE inner joins
across FOUR tables in one statement, and that's a genuinely different thing
to picture than a single two-circle Venn diagram - so this diagram exists
specifically to make the chaining itself visible: how one row's two foreign
keys (AccountID, CategoryID) fan out into two independent lookup paths,
one of which itself chains a second hop (Accounts -> Users), and how all
three paths land back together in a single combined output row.

Uses the real, already-confirmed data from Pieces 1-11 (not placeholder
data) - the same 5 Transactions rows this query actually returned.

Produces: piece12_join_chain.png
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

INK = "#1C2321"
INK_SOFT = "#525B57"
INK_FAINT = "#8A9490"
PAPER = "#FBFAF6"
WHITE = "#FFFFFF"
BORDER = "#C9C4B6"
GOOD = "#2E7D4F"

COLOR = {
    "Transactions": "#6A5590",  # violet
    "Accounts": "#3B6EA5",      # steel blue
    "Users": "#2B6E6E",         # teal
    "Categories": "#9C6B0B",    # amber
}

W, H = 220, 190


def new_fig():
    fig, ax = plt.subplots(figsize=(W / 10, H / 10), dpi=200)
    fig.patch.set_facecolor(PAPER)
    ax.set_facecolor(PAPER)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.axis("off")
    return fig, ax


def save(fig, name):
    plt.tight_layout(rect=[0, 0, 1, 0.97])
    fig.savefig(name, facecolor=PAPER, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)


def box(ax, x, y, w, h, color, lw=1.8, fc=WHITE, z=3):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                                 linewidth=lw, edgecolor=color, facecolor=fc, zorder=z))


def arrow(ax, p1, p2, color, label=None, label_pos=0.5, label_dy=1.8, lw=1.8, curve=0.0):
    conn = f"arc3,rad={curve}" if curve else None
    ax.add_patch(FancyArrowPatch(p1, p2, arrowstyle="-|>", mutation_scale=14,
                                  linewidth=lw, color=color, zorder=2,
                                  connectionstyle=conn, shrinkA=2, shrinkB=2))
    if label:
        mx = p1[0] + (p2[0] - p1[0]) * label_pos
        my = p1[1] + (p2[1] - p1[1]) * label_pos
        ax.text(mx, my + label_dy, label, fontsize=7.3, color=color, ha="center", va="bottom",
                zorder=6, bbox=dict(boxstyle="round,pad=0.15", fc=PAPER, ec="none"))


def section_title(ax, x, y, text):
    ax.text(x, y, text, fontsize=12, fontweight="bold", color=INK, ha="left", va="bottom")


def gen_join_chain():
    fig, ax = new_fig()
    fig.suptitle("FinanceTrackerDB - Piece 12: chaining three inner joins (Transactions -> Accounts -> Users, and Transactions -> Categories)",
                  fontsize=13.5, fontweight="bold", color=INK, x=0.015, y=0.99, ha="left")

    # ===================================================================
    # SECTION 1  (band: y = 150 -> 184)
    # ===================================================================
    section_title(ax, 6, 186, "1. The shape of the chain - one driving table, two independent lookup paths")

    box(ax, 6, 160, 36, 16, COLOR["Transactions"])
    ax.text(24, 174.5, "Transactions", fontsize=10, fontweight="bold",
            color=COLOR["Transactions"], ha="center", va="center")
    ax.text(24, 167.5, "(the driving table -\nevery row starts here)", fontsize=8.2,
            color=INK, ha="center", va="center")

    box(ax, 78, 168, 34, 12, COLOR["Accounts"])
    ax.text(95, 174, "Accounts", fontsize=10.2, color=COLOR["Accounts"], ha="center", va="center",
            fontweight="bold")
    box(ax, 148, 168, 34, 12, COLOR["Users"])
    ax.text(165, 174, "Users", fontsize=10.2, color=COLOR["Users"], ha="center", va="center",
            fontweight="bold")

    box(ax, 78, 150, 34, 12, COLOR["Categories"])
    ax.text(95, 156, "Categories", fontsize=10.2, color=COLOR["Categories"], ha="center", va="center",
            fontweight="bold")

    arrow(ax, (42, 173), (78, 174), COLOR["Accounts"], "hop 1: t.AccountID = a.AccountID")
    arrow(ax, (112, 174), (148, 174), COLOR["Users"], "hop 2: a.UserID = u.UserID")
    arrow(ax, (42, 165), (78, 157), COLOR["Categories"], "hop 3 (separate branch):\nt.CategoryID = c.CategoryID",
          label_pos=0.42, label_dy=2.4)

    ax.text(6, 146,
            "Hop 1 and hop 2 chain together - Accounts hands UserID on to Users - that's the \"Transactions -> Accounts -> Users\" path.\n"
            "Hop 3 is a completely separate lookup straight off Transactions - it never touches Accounts or Users at all.\n"
            "SQL Server is free to actually run these hops in whatever order is fastest; the result is identical either way.",
            fontsize=8.6, color=INK_SOFT, ha="left", va="top", linespacing=1.5)

    # ===================================================================
    # SECTION 2  (band: y = 92 -> 134)
    # ===================================================================
    section_title(ax, 6, 138, "2. Worked example - tracing the real TransactionID 1 row through all three hops")

    y_mid = 104
    bh = 13

    box(ax, 6, y_mid - bh / 2, 32, bh, COLOR["Transactions"])
    ax.text(22, y_mid + bh / 2 - 3.0, "TransactionID 1", fontsize=9, fontweight="bold",
            color=COLOR["Transactions"], ha="center", va="center")
    ax.text(22, y_mid - 1.3, "AccountID = 1\nCategoryID = 4\nAmount = -1500.00", fontsize=7.8,
            color=INK, ha="center", va="center", linespacing=1.5)

    box(ax, 64, y_mid + 10, 36, bh, COLOR["Accounts"])
    ax.text(82, y_mid + 10 + bh / 2 - 3.0, "Accounts: AccountID = 1", fontsize=8.4, fontweight="bold",
            color=COLOR["Accounts"], ha="center", va="center")
    ax.text(82, y_mid + 10 + 1.5, "-> Checking\n-> UserID = 1", fontsize=8.0,
            color=INK, ha="center", va="center", linespacing=1.5)

    box(ax, 128, y_mid + 10, 36, bh, COLOR["Users"])
    ax.text(146, y_mid + 10 + bh / 2 - 3.0, "Users: UserID = 1", fontsize=8.4, fontweight="bold",
            color=COLOR["Users"], ha="center", va="center")
    ax.text(146, y_mid + 10 + 1.5, "-> Anirruddha Banerjee", fontsize=8.0,
            color=INK, ha="center", va="center")

    box(ax, 64, y_mid - 10 - bh, 36, bh, COLOR["Categories"])
    ax.text(82, y_mid - 10 - bh + bh - 3.0, "Categories: CategoryID = 4", fontsize=8.4, fontweight="bold",
            color=COLOR["Categories"], ha="center", va="center")
    ax.text(82, y_mid - 10 - bh + 3.0, "-> Rent", fontsize=8.0, color=INK, ha="center", va="center")

    box(ax, 176, y_mid - bh / 2 - 2, 42, bh + 10, GOOD, fc=WHITE)
    ax.text(197, y_mid + bh / 2 + 4, "combined output row", fontsize=8.6, fontweight="bold",
            color=GOOD, ha="center", va="center")
    ax.text(197, y_mid - 1,
            "Anirruddha Banerjee | Checking | Rent\n2026-09-01 | -1500.00\nSeptember rent",
            fontsize=7.6, color=INK, ha="center", va="center", linespacing=1.6)

    arrow(ax, (38, y_mid + 4), (64, y_mid + 10 + bh / 2), COLOR["Accounts"], "MATCH\nFOUND", label_pos=0.45, label_dy=0)
    arrow(ax, (100, y_mid + 10 + bh / 2), (128, y_mid + 10 + bh / 2), COLOR["Users"], "MATCH FOUND")
    arrow(ax, (38, y_mid - 4), (64, y_mid - 10 - bh / 2), COLOR["Categories"], "MATCH\nFOUND", label_pos=0.45, label_dy=0)

    arrow(ax, (164, y_mid + 10 + bh / 2 - 2), (176, y_mid + bh / 2 + 2), GOOD, curve=-0.2)
    arrow(ax, (100, y_mid - 10 - bh / 2 + 2), (176, y_mid - 2), GOOD, curve=0.18)

    ax.text(6, y_mid - 10 - bh - 6,
            "Every one of the 5 real Transactions rows goes through this exact same three-hop trace - this is just the one with the\n"
            "most dramatic Amount, chosen to make the trace easy to follow. All 5 found a match on every hop (see Section 3 below).",
            fontsize=8.3, color=INK_FAINT, ha="left", va="top", linespacing=1.5)

    # ===================================================================
    # SECTION 3  (band: y = 4 -> 82)
    # ===================================================================
    section_title(ax, 6, 66, "3. Final result - all 5 real rows, every column's source table color-coded")

    headers = ["TxnID", "UserName", "AccountName", "CategoryName", "Date", "Amount", "Description"]
    header_colors = [COLOR["Transactions"], COLOR["Users"], COLOR["Accounts"], COLOR["Categories"],
                      COLOR["Transactions"], COLOR["Transactions"], COLOR["Transactions"]]
    col_x = [8, 24, 60, 94, 130, 158, 180]
    rows = [
        ["1", "Anirruddha Banerjee", "Checking", "Rent", "2026-09-01", "-1500.00", "September rent"],
        ["2", "Anirruddha Banerjee", "Checking", "Groceries", "2026-09-05", "-120.50", "Weekly groceries"],
        ["3", "Anirruddha Banerjee", "Checking", "Groceries", "2026-09-19", "-95.10", "Groceries top-up"],
        ["4", "Anirruddha Banerjee", "Savings", "Movies", "2026-09-10", "-45.00", "Movie night"],
        ["5", "Test User Two", "Checking", "Groceries", "2026-09-12", "-80.25", "Groceries"],
    ]

    table_top = 62
    row_h = 5.0
    header_h = 6.0
    table_h = header_h + row_h * len(rows) + 2
    table_w = 206
    box(ax, 6, table_top - table_h, table_w, table_h, INK_FAINT, lw=1.2)

    header_y = table_top - header_h / 2 - 1
    for cx, label, c in zip(col_x, headers, header_colors):
        ax.text(cx, header_y, label, fontsize=8.6, fontweight="bold", color=c, ha="left", va="center")
    rule_y = table_top - header_h
    ax.plot([7, 6 + table_w - 1], [rule_y, rule_y], color=BORDER, lw=0.9, zorder=4)

    for ri, row in enumerate(rows):
        ry = rule_y - row_h * ri - row_h / 2
        for cx, val, c in zip(col_x, row, header_colors):
            ax.text(cx, ry, val, fontsize=8.3, color=INK, ha="left", va="center")

    takeaway_y = table_top - table_h - 6
    ax.text(6, takeaway_y,
            "Key takeaways:\n"
            "1. Each inner join only ever looks at the two tables immediately on either side of it - the Accounts/Users hop has no idea\n"
            "   Categories even exists, and vice versa.\n"
            "2. Order doesn't matter here - every hop matches a real FK to its real PK, so SQL Server can run them in any sequence and\n"
            "   still land on the same 5 rows.\n"
            "3. Nothing was dropped because referential integrity (Pieces 3 and 8) already guaranteed every AccountID/UserID/CategoryID\n"
            "   in Transactions points at a real row - the left/right/full outer pieces coming next will deliberately start from a table\n"
            "   that has unmatched rows, so the outer-join difference finally has something real to show.",
            fontsize=8.4, color=INK_SOFT, ha="left", va="top", linespacing=1.6)

    save(fig, "piece12_join_chain.png")


if __name__ == "__main__":
    gen_join_chain()
    print("wrote piece12_join_chain.png")
