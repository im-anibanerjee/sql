"""
FinanceTrackerDB - populated schema diagram: every table's REAL data
(from the real pieces confirmed in the build notes), with every foreign
key value carrying a small colored badge that matches the color of the
table/row it resolves to.

Why badges instead of drawn lines: the ER diagram (gen_er_diagram.py)
draws one line per table-to-table relationship (6 of them) and that's
already as busy as it should get. At the row level there are ~22
individual FK-to-PK links across these 5 tables - drawing all of them
as crossing lines would be unreadable. A colored badge (same color as
the table it points into, same number as the row it points at) carries
the same information without a single crossing line.

The full precise version (exact row-to-row text) lives in the "Populated
Schema" section of finance tracker build notes.md; this diagram is the
at-a-glance companion, not the source of truth - if the two ever
disagree, the build notes (and the real SSMS output behind them) win.

Produces: populated_schema.png
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Circle

INK = "#1C2321"
INK_SOFT = "#525B57"
INK_FAINT = "#8A9490"
PAPER = "#FBFAF6"
WHITE = "#FFFFFF"
BORDER = "#C9C4B6"

# one distinct color per table, reused as both the table's own header
# color and the badge color anyone else uses to point at one of its rows
COLOR = {
    "Users": "#2B6E6E",         # teal
    "Accounts": "#3B6EA5",      # steel blue
    "Categories": "#9C6B0B",    # amber
    "Transactions": "#6A5590",  # violet
    "Budgets": "#A54B4B",       # rose
}

ROW_H = 5.2
PAD = 2.4


def new_fig(w, h):
    fig, ax = plt.subplots(figsize=(w, h), dpi=200)
    fig.patch.set_facecolor(PAPER)
    ax.set_facecolor(PAPER)
    ax.set_xlim(0, w * 10)
    ax.set_ylim(0, h * 10)
    ax.axis("off")
    return fig, ax


def save(fig, name):
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(name, facecolor=PAPER, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)


def badge(ax, x, y, number, color, r=1.55):
    ax.add_patch(Circle((x, y), r, facecolor=color, edgecolor="none", zorder=6))
    ax.text(x, y, str(number), fontsize=6.6, color=WHITE, ha="center", va="center",
            fontweight="bold", zorder=7)


def table_box(ax, x, y, table_name, col_labels, col_widths, rows, pk_col=0, fk_cols=None):
    """rows: list of row-dicts, each cell is either a plain string, or
    (text, ref_table, ref_number) for a cell that should carry a badge
    pointing at another (or the same) table's row."""
    fk_cols = fk_cols or {}
    color = COLOR[table_name]
    w = sum(col_widths)
    header_h = 5.6
    h = header_h + ROW_H * len(rows) + PAD

    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                                 linewidth=1.8, edgecolor=color, facecolor=WHITE, zorder=3))
    ax.text(x + w / 2, y + h + 1.3, f"{table_name}  ({len(rows)} rows)", fontsize=12,
            fontweight="bold", color=color, ha="center", va="bottom")

    # column headers
    header_y = y + h - PAD - header_h / 2
    cx = x
    col_x = []
    for cw, lab in zip(col_widths, col_labels):
        col_x.append(cx)
        is_key = (col_labels.index(lab) == pk_col) or (col_labels.index(lab) in fk_cols)
        ax.text(cx + 0.7, header_y, lab, fontsize=7.6, fontweight="bold",
                color=color, ha="left", va="center")
        cx += cw
    ax.plot([x + 0.2, x + w - 0.2], [y + h - PAD - header_h, y + h - PAD - header_h],
            color=color, lw=1.1, zorder=4)

    # rows
    for ri, row in enumerate(rows):
        ry = y + h - PAD - header_h - (ri + 1) * ROW_H + ROW_H * 0.1
        for ci, cell in enumerate(row):
            cx0 = col_x[ci] + 0.7
            if isinstance(cell, tuple):
                text, ref_table, ref_num = cell
                ax.text(cx0, ry + ROW_H / 2 - 0.1, str(text), fontsize=7.8,
                        color=INK if ci != pk_col else color,
                        fontweight="bold" if ci == pk_col else "normal",
                        ha="left", va="center", zorder=5)
                # badge placed just after the text
                badge_x = cx0 + 2.6 + 0.9 * len(str(text))
                badge(ax, badge_x, ry + ROW_H / 2 - 0.1, ref_num, COLOR[ref_table])
            else:
                ax.text(cx0, ry + ROW_H / 2 - 0.1, str(cell), fontsize=7.8,
                        color=color if ci == pk_col else INK,
                        fontweight="bold" if ci == pk_col else "normal",
                        ha="left", va="center", zorder=5)
        if ri == 0:
            pass
    if len(rows) > 1:
        for ri in range(1, len(rows)):
            ry_line = y + h - PAD - header_h - ri * ROW_H
            ax.plot([x + 0.2, x + w - 0.2], [ry_line, ry_line], color=BORDER, lw=0.6, zorder=4)

    return {"x": x, "y": y, "w": w, "h": h}


def gen_populated_schema():
    fig, ax = new_fig(21.0, 10.8)
    fig.suptitle("FinanceTrackerDB - populated schema: real rows, every foreign key badge-matched to the exact row it points at",
                  fontsize=13.5, fontweight="bold", color=INK, x=0.015, y=0.99, ha="left")

    # ---- Users ----
    users_rows = [
        ["1", "Anirruddha Banerjee"],
        ["2", "Test User Two"],
    ]
    t_users = table_box(ax, 6, 78, "Users", ["UserID", "UserName"], [6, 30], users_rows, pk_col=0)

    # ---- Accounts ----
    accounts_rows = [
        ["1", ("1", "Users", "1"), "Checking"],
        ["2", ("1", "Users", "1"), "Savings"],
        ["3", ("2", "Users", "2"), "Checking"],
    ]
    t_accounts = table_box(ax, 54, 72, "Accounts", ["AccountID", "UserID", "AccountName"],
                            [8, 10, 20], accounts_rows, pk_col=0, fk_cols={1})

    # ---- Categories ----
    categories_rows = [
        ["1", "Essentials", "—"],
        ["2", "Entertainment", "—"],
        ["3", "Groceries", ("1", "Categories", "1")],
        ["4", "Rent", ("1", "Categories", "1")],
        ["5", "Movies", ("2", "Categories", "2")],
    ]
    t_categories = table_box(ax, 108, 66, "Categories", ["CategoryID", "CategoryName", "ParentID"],
                              [8, 24, 10], categories_rows, pk_col=0, fk_cols={2})

    # ---- Transactions ----
    transactions_rows = [
        ["1", ("1", "Accounts", "1"), ("4", "Categories", "4"), "-1500.00", "Rent"],
        ["2", ("1", "Accounts", "1"), ("3", "Categories", "3"), "-120.50", "Groceries"],
        ["3", ("1", "Accounts", "1"), ("3", "Categories", "3"), "-95.10", "Groceries"],
        ["4", ("2", "Accounts", "2"), ("5", "Categories", "5"), "-45.00", "Movies"],
        ["5", ("3", "Accounts", "3"), ("3", "Categories", "3"), "-80.25", "Groceries"],
    ]
    t_transactions = table_box(ax, 20, 26, "Transactions",
                                ["TxnID", "AccountID", "CategoryID", "Amount", "Category"],
                                [7, 10, 10, 11, 20], transactions_rows, pk_col=0, fk_cols={1, 2})

    # ---- Budgets ----
    budgets_rows = [
        ["1", ("1", "Users", "1"), ("3", "Categories", "3"), "400.00"],
        ["2", ("1", "Users", "1"), ("4", "Categories", "4"), "1500.00"],
        ["3", ("2", "Users", "2"), ("5", "Categories", "5"), "100.00"],
    ]
    t_budgets = table_box(ax, 120, 36, "Budgets", ["BudgetID", "UserID", "CategoryID", "Amount"],
                           [8, 10, 10, 11], budgets_rows, pk_col=0, fk_cols={1, 2})

    # ---- legend ----
    legend_y = 14
    ax.text(6, legend_y + 5,
            "How to read a badge: a colored circle next to a foreign-key value is colored like the TABLE it points into, "
            "and numbered like the exact ROW in that table.",
            fontsize=8.6, color=INK_SOFT, ha="left", va="bottom")
    lx = 6
    for name in ["Users", "Accounts", "Categories", "Transactions", "Budgets"]:
        badge(ax, lx + 1.2, legend_y, "#", COLOR[name])
        ax.text(lx + 3.2, legend_y, name, fontsize=8.6, color=COLOR[name], fontweight="bold",
                ha="left", va="center")
        lx += 3.2 + 2.4 * len(name) + 4

    ax.text(6, 4,
            "Real chain to read: Transaction #1 (-1500.00, \"Rent\") -> Account #1 (badge, blue) -> that account belongs to User #1 (Accounts table, blue badge) -> Anirruddha Banerjee.\n"
            "Transaction #1 is also tagged Category #4 \"Rent\" (amber badge) -> Category #4 is a child of Category #1 \"Essentials\" (Categories table's own amber self-badge).",
            fontsize=7.8, color=INK_FAINT, ha="left", va="bottom")

    save(fig, "populated_schema.png")


if __name__ == "__main__":
    gen_populated_schema()
    print("wrote populated_schema.png")
