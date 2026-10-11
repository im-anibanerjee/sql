"""
FinanceTrackerDB - entity relationship diagram (the blueprint), v2.

v1 drew relationships box-edge to box-edge, which looked clean but didn't
show WHICH column in one table points at WHICH column in the other -
exactly what was confusing about it. v2 fixes that: every line starts at
the exact row of the foreign-key column and ends at the exact row of the
primary-key column it references, with a text label on the line spelling
out "Table.Column -> Table.Column" so there is no guessing.

Same house palette as the doc 06/07 diagrams, so it still reads as part
of the same series.

Produces: er_diagram.png
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

INK = "#1C2321"
INK_SOFT = "#525B57"
INK_FAINT = "#8A9490"
PAPER = "#FBFAF6"
WHITE = "#FFFFFF"
BORDER = "#C9C4B6"
ACCENT = "#2B6E6E"
AMBER = "#9C6B0B"
VIOLET = "#6A5590"

ROW_H = 4.6
PAD = 2.2


def new_fig(w, h):
    fig, ax = plt.subplots(figsize=(w, h), dpi=200)
    fig.patch.set_facecolor(PAPER)
    ax.set_facecolor(PAPER)
    ax.set_xlim(0, w * 10)
    ax.set_ylim(0, h * 10)
    ax.axis("off")
    return fig, ax


def save(fig, name):
    plt.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(name, facecolor=PAPER, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)


def box(ax, x, y, w, h, color, lw=1.6, z=3):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.1",
                                 linewidth=lw, edgecolor=color, facecolor=WHITE, zorder=z))


def table(ax, x, y, w, name, cols, color):
    """cols: list of (label, is_key). Returns dict with box geometry and
    the vertical center of every row, so relationship lines can target an
    exact row instead of a generic box edge."""
    h = ROW_H * len(cols) + 2.4
    box(ax, x, y, w, h, color)
    ax.text(x + w / 2, y + h + 1.4, name, fontsize=12.5, fontweight="bold",
            color=color, ha="center", va="bottom")
    rows = []
    for i, (label, is_key) in enumerate(cols):
        ry = y + h - PAD - (i + 1) * ROW_H
        ax.text(x + 0.9, ry + ROW_H * 0.15, label, fontsize=8.6,
                color=color if is_key else INK_SOFT,
                fontweight="bold" if is_key else "normal", va="center", ha="left", zorder=4)
        rows.append(ry + ROW_H / 2)
        if i == 0:
            ax.plot([x + 0.2, x + w - 0.2], [ry, ry], color=BORDER, lw=0.9, zorder=4)
    return {"x": x, "y": y, "w": w, "h": h, "rows": rows}


def card(ax, x, y, text, color):
    ax.text(x, y, text, fontsize=8.5, color=color, ha="center", va="center",
            style="italic", zorder=6, bbox=dict(boxstyle="round,pad=0.08", fc=PAPER, ec="none"))


def label(ax, x, y, text, color):
    ax.text(x, y, text, fontsize=7.8, color=color, ha="center", va="center", zorder=6,
            bbox=dict(boxstyle="round,pad=0.15", fc=PAPER, ec=color, lw=0.7))


def connector(ax, p1, p2, mid_x, color):
    """Right-angle (Z-shaped) line from the FK row (p1) to the PK row it
    references (p2), via one horizontal-vertical-horizontal path, with an
    arrowhead landing exactly on the PK row."""
    x1, y1 = p1
    x2, y2 = p2
    ax.plot([x1, mid_x, mid_x, x2], [y1, y1, y2, y2], color=color, lw=1.8, zorder=2,
            solid_capstyle="round", solid_joinstyle="round")
    ax.annotate("", xy=(x2, y2), xytext=(mid_x, y2),
                arrowprops=dict(arrowstyle="-|>", color=color, lw=1.8, mutation_scale=13), zorder=3)


def gen_er_diagram():
    fig, ax = new_fig(20.0, 10.2)
    fig.suptitle("FinanceTrackerDB - entity relationship diagram (each line: exact FK column -> exact PK column it must match)",
                  fontsize=13.5, fontweight="bold", color=INK, x=0.02, y=0.985, ha="left")

    users = table(ax, 8, 70, 30, "Users", [
        ("UserID (PK)", True), ("UserName", False), ("Email", False), ("DateJoined", False),
    ], ACCENT)

    accounts = table(ax, 8, 30, 30, "Accounts", [
        ("AccountID (PK)", True), ("UserID (FK)", False), ("AccountName", False),
        ("AccountType", False), ("Balance", False), ("DateOpened", False),
    ], ACCENT)

    transactions = table(ax, 66, 22, 36, "Transactions", [
        ("TransactionID (PK)", True), ("AccountID (FK)", False), ("CategoryID (FK)", False),
        ("TransactionDate", False), ("Amount", False), ("Description", False),
    ], VIOLET)

    categories = table(ax, 140, 70, 30, "Categories", [
        ("CategoryID (PK)", True), ("CategoryName", False), ("ParentCategoryID (FK, self)", False),
    ], AMBER)

    budgets = table(ax, 140, 30, 30, "Budgets", [
        ("BudgetID (PK)", True), ("UserID (FK)", False), ("CategoryID (FK)", False),
        ("MonthYear", False), ("BudgetAmount", False),
    ], VIOLET)

    # ================= relationships: exact row -> exact row =================

    # 1. Accounts.UserID (row 1) -> Users.UserID (row 0)
    p1 = (accounts["x"] + accounts["w"], accounts["rows"][1])
    p2 = (users["x"] + users["w"], users["rows"][0])
    connector(ax, p1, p2, mid_x=44, color=ACCENT)
    card(ax, p1[0] + 2.2, p1[1], "*", ACCENT)
    card(ax, p2[0] + 2.2, p2[1], "1", ACCENT)
    label(ax, 44, (p1[1] + p2[1]) / 2, "Accounts.UserID -> Users.UserID", ACCENT)

    # 2. Transactions.AccountID (row 1) -> Accounts.AccountID (row 0)
    p1 = (transactions["x"], transactions["rows"][1])
    p2 = (accounts["x"] + accounts["w"], accounts["rows"][0])
    connector(ax, p1, p2, mid_x=56, color=ACCENT)
    card(ax, p1[0] - 2.2, p1[1], "*", ACCENT)
    card(ax, p2[0] + 2.2, p2[1], "1", ACCENT)
    label(ax, 56, (p1[1] + p2[1]) / 2, "Transactions.AccountID\n-> Accounts.AccountID", ACCENT)

    # 3. Transactions.CategoryID (row 2) -> Categories.CategoryID (row 0)
    p1 = (transactions["x"] + transactions["w"], transactions["rows"][2])
    p2 = (categories["x"], categories["rows"][0])
    connector(ax, p1, p2, mid_x=116, color=AMBER)
    card(ax, p1[0] + 2.2, p1[1], "*", AMBER)
    card(ax, p2[0] - 2.2, p2[1], "1", AMBER)
    label(ax, 116, (p1[1] + p2[1]) / 2, "Transactions.CategoryID\n-> Categories.CategoryID", AMBER)

    # 4. Budgets.UserID (row 1) -> Users.UserID (row 0)
    p1 = (budgets["x"], budgets["rows"][1])
    p2 = (users["x"] + users["w"], users["rows"][0])
    connector(ax, p1, p2, mid_x=128, color=ACCENT)
    card(ax, p1[0] - 2.2, p1[1], "*", ACCENT)
    card(ax, p2[0] + 2.2, p2[1] + 2.4, "1", ACCENT)
    label(ax, 128, p1[1] - 3.2, "Budgets.UserID\n-> Users.UserID", ACCENT)

    # 5. Budgets.CategoryID (row 2) -> Categories.CategoryID (row 0)
    p1 = (budgets["x"] + budgets["w"], budgets["rows"][2])
    p2 = (categories["x"] + categories["w"], categories["rows"][0])
    connector(ax, p1, p2, mid_x=178, color=AMBER)
    card(ax, p1[0] + 2.2, p1[1], "*", AMBER)
    card(ax, p2[0] + 2.2, p2[1], "1", AMBER)
    label(ax, 178, (p1[1] + p2[1]) / 2, "Budgets.CategoryID\n-> Categories.CategoryID", AMBER)

    # 6. Categories self-reference: ParentCategoryID (row 2) -> CategoryID (row 0)
    #    Routed over the TOP of the box so it never crosses relationship 5's line.
    top = categories["y"] + categories["h"]
    loop = FancyArrowPatch((categories["x"] + 24, top), (categories["x"] + 6, top),
                            connectionstyle="arc3,rad=0.7", arrowstyle="-|>",
                            mutation_scale=15, linewidth=1.8, color=AMBER, zorder=2)
    ax.add_patch(loop)
    card(ax, categories["x"] + 24, top + 2.0, "*", AMBER)
    card(ax, categories["x"] + 6, top + 2.0, "1", AMBER)
    label(ax, categories["x"] + 15, top + 6.4,
          "self-join: Categories.ParentCategoryID\n-> Categories.CategoryID (the hierarchy)", AMBER)

    # ---- legend ----
    ax.text(8, 4,
            "PK = primary key, one unique row   |   FK = foreign key, must match an existing PK value in the other table\n"
            "every arrow runs FROM the foreign-key column TO the primary-key column it has to match   |   "
            "1 = the one PK row   *  = the many rows that can point to it",
            fontsize=8.6, color=INK_FAINT, ha="left", va="bottom")

    save(fig, "er_diagram.png")


if __name__ == "__main__":
    gen_er_diagram()
    print("wrote er_diagram.png")
