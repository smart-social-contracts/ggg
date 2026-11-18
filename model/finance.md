# Finance

One part of [the GGG model](../README.md#the-model).

## 5. Finance

### Entities

| Entity | Fields | Notes | Example |
|---|---|---|---|
| `Treasury` | `id` (`1`), `config` (Json: epoch length, anchor month, source fund, auto-allocate; on a capital, its sweep rules, §10), `debt_outstanding` | Singleton. `debt_outstanding` is the sum of the active loans' `outstanding`. | Monthly epochs, source fund `ROOT`, auto-allocation on, 420,000 REALM of debt |
| `Token` | `id` (symbol), `ledger`, `indexer`, `decimals`, `fee` | A fungible ledger the realm uses (ICRC-1). | `ckBTC`: ledger `mxzaz-…`, 8 decimals, fee 10 |
| `NFTToken` | `id` (symbol), `canister`, `name`, `description`, `transferable`, `required_license` (licence type or empty), `supply_cap`, `total_supply` | An NFT ledger (ICRC-7) the realm mints into. | `LAND` (transferable); `CRED` (non-transferable, minting needs a licence) |
| `Fund` | `id` (code), `name`, `kind` (general, special revenue, …), `department` → `Department`, `balances` (Json: running balance per token), `allocation_rule` → `AllocationRule` | | `ROADS`: special revenue, owned by Infrastructure |
| `FiscalPeriod` | `id`, `name`, `starts_at`, `ends_at`, `status`, `statements` (Json: running totals), `source_hash` (chained over its entries) | | `FY2026`: 2026-01-01 to 2026-12-31, `open` |
| `Budget` | `id`, `fund` → `Fund`, `period` → `FiscalPeriod`, `category`, `kind` (`revenue` or `expense`), `planned`, `actual`, `status`, `proposal` → `Proposal`, `reserved`, `committed` | One line of a period's budget: `category` is the realm's word for what (capital, salaries, property tax), `kind` whether the money comes in or goes out. An adopted expense line's `reserved` and `committed` money and its `actual` leave its available credit, `planned - reserved - committed - actual`, never negative (I-FIN-9). | Roads FY2026, expense, capital: planned 300,000, reserved 40,000, committed 90,000, actual 120,500, so 49,500 available, `adopted` |
| `AllocationRule` | `id`, `source_fund`, `rules` (Json: fund and `share`), `status`, `proposal` → `Proposal` | How revenue is split between funds. Shares are in hundred-millionths and add up to at most 100 000 000. | From `ROOT`: 30% `WELFARE`, 20% `ROADS`, 50% `GENERAL` |
| `LedgerEntry` | `id`, `transaction`, `kind` (asset, liability, equity, revenue, expense), `category`, `debit`, `credit`, `symbol`, `fund` → `Fund`, `period` → `FiscalPeriod`, `transfer` → `Transfer`, `invoice` → `Invoice`, `user` → `User`, `organization` → `Organization`, `contract` → `Contract`, `case` → `Case`, `penalty` → `Penalty`, `appeal` → `Appeal`, `sweep` → `Sweep`, `at`, `description` | Double entry. At most one of the source references is set. | Tx `T-88`: debit `ROADS` capital expense 50,000, credit cash 50,000, contract `C-9` |
| `Invoice` | `id`, `payer` (`Entity:id`), `amount`, `symbol`, `items` (lines, each an `InvoiceItem`: `concept`, `amount` (signed: a discount is negative), `quantity`, `unit`, `legislation`), `facts` (Json), `due_at`, `status`, `reason` (`Entity:id`), `paid_at`, `payment` (Json) | Paid into the subaccount derived from its `id`. At least one item, and the items sum to `amount`, which is never negative; `facts` is what legislation reads about the invoice beyond its items. | `INV-301`: Alice owes 120 REALM property tax, due 2026-12-31, `pending`: lines `property_tax` 150 and `large_family_bonus` −30 |
| `Transfer` | `id`, `sender`, `to`, `symbol`, `amount`, `ledger_tx`, `invoice` → `Invoice`, `status`, `at`, `payroll` (the payroll run), `due_at`, `budget` → `Budget`, `committed`, `contract` → `Contract` | `budget` is the line it is charged to, `committed` whether it drew on that line's committed money (I-FIN-9). A `scheduled` transfer is owed by its `due_at` (I-FIN-10). `contract` is the contract it pays, whose value the payments never exceed (I-FIN-11). | 50,000 REALM from `ROADS` to BuildCo, ledger tx 18234, `completed`; 12,000 REALM to BuildCo for its January certificate, `scheduled`, due 2026-03-15, charged to Roads FY2026 capital from its committed money |
| `Trade` | `id`, `contract` → `Contract`, `leg_a` → `Transfer`, `leg_b` → `Transfer`, `status` | An exchange of two transfers. | `C-9` milestone: realm pays 10,000 REALM, BuildCo hands over the road deed NFT |
| `PaymentAccount` | `id`, `owner` (`Entity:id`), `network`, `address`, `symbol`, `label`, `verified` | External accounts for payouts. | Bob's ckBTC payout address, verified |
| `FinancialReport` | `id`, `kind`, `period` → `FiscalPeriod`, `as_of`, `statements` (Json), `source_hash`, `issued_by`, `supersedes` → `FinancialReport` | Frozen statements. | FY2025 closing statements issued by Finance, `sha256:77d0…` |
| `TaxPolicy` | `id`, `status`, `document` (Json), `description`, `proposal` → `Proposal`, `adopted_at`, `taxes` (typed entries, each a `TaxEntry`: `code`, `kind` (the realm's word, e.g. `tax`, `fee`, `surcharge`), `subject` (the entity assessed, e.g. `Land`, `User`, `Organization`), `rate`, `amount`, `facts` (Json)) | Typed entries, which legislation checks one by one; the codex computes each taxpayer's amount. `document` holds the policy's text and whatever else the realm records about it, as Json; the entries are what the rules and the assessment read. | `TAX-POLICY-3`: `property_tax` (tax on `Land`, rate 0.4 %) and `waste_fee` (fee on `User`, 120 REALM a year), `adopted` |
| `TaxDeclaration` | `id`, `declarant` (`Entity:id`), `period`, `base`, `amount`, `status`, `invoice` → `Invoice` | Self-declared bases (revenue, payroll). | Clinic B declares 182,000 revenue for 2026-Q3 → `INV-412` |
| `Loan` | `id`, `lender` → `External`, `amount`, `symbol`, `term` (a Period), `rate`, `fund` → `Fund`, `outstanding`, `status`, `facts` (Json) | Money the realm owes an outside lender (§11), in the accounting currency, so the treasury's `debt_outstanding` is one sum. The money itself moves outside the realm; GGG records the debt and its repayments. | `LOAN-2`: 500,000 REALM from Bank A over 10 years at 3.2 %, into `ROADS`, 420,000 outstanding, `active` |

There is no balance entity: the ledgers are the source of truth.

### Lifecycles

- `Invoice.status`: `pending` → `paid` | `overdue` | `cancelled`; `overdue` → `paid` | `cancelled`.
- `Trade.status`: `pending` → `completed` | `failed`.
- `Transfer.status`: `sending` (ledger call in flight) → `completed` | `failed`; `sending` → `pending` (ledger refused) → `failed` (reverted); `scheduled` (owed) → `sending` (`transfer_pay`) | `cancelled` (`transfer_revert`).
- `Budget.status`: `draft` → `proposed` → `adopted` → `amended` (replaced by a later adopted line of
  its fund, period and category: `budget_amend` or a later budget) | `closed`; `extended` (copied
  from the previous period by `budget_extend`) → `amended` (replaced by the fund's adopted budget) |
  `closed` (with its period).
- `FiscalPeriod.status`: `open` → `closed` → `archived`.
- `AllocationRule.status`, `TaxPolicy.status`: `draft` → `proposed` → `adopted` → `superseded`.
- `TaxDeclaration.status`: `filed` → `assessed` → `settled` | `disputed`.
- `Loan.status`: `active` → `repaid`.

### Operations

| Operation | Permission | Flags | Example |
|---|---|---|---|
| `treasury_view`, `ledger_view`, `report_view` | `treasury.view` | read, delegable | Finance sees `ROOT` 1.2M, `ROADS` 180k REALM |
| `treasury_configure`, `token_register`, `nft_token_register` | `treasury.manage` | governed, delegable | Quarterly allocation epochs; register ckUSDC; on the capital, sweep every quarter's `GENERAL` into its own |
| `transfer_create` (from a fund) | `transfer.create` | delegable, governed | `{fund: "ROADS", to: "buildco", amount: 50000}` → proposal under Infrastructure's policy |
| `transfer_revert` | `transfer.delete` | governed, delegable | Cancel a duplicate pending payment; cancel a scheduled one, unpaid |
| `transfer_pay` | `transfer.create` | delegable | Pay BuildCo's scheduled 12,000 REALM on 10 March, before it is due |
| `transfer_list` | `treasury.view` | read, delegable | What Roads owes: 3 scheduled transfers, 31,000 REALM, the first due 15 March |
| `invoice_create` | `treasury.manage` | delegable | Registration fee: 10 REALM for new member Bob |
| `invoice_item_add` | `treasury.manage` | delegable | The sanitation charge joins Alice's pending water invoice as a second line |
| `invoice_check` (own) | `self.invoice_refresh` | delegable | Alice paid `INV-301` → `paid` |
| `invoice_refresh` (any) | `invoice.refresh` | delegable | Finance re-checks all pending invoices |
| `my_invoices` | `self.data_view` | read, delegable | Alice: `INV-301`, 120 REALM, due 31 Dec |
| `fund_create`, `period_open`, `period_close` | `org.manage_budget` | governed, delegable | Create fund `WELFARE`; close `FY2025` |
| `budget_draft`, `budget_propose` (the draft lines of a period together: a fund's, or every fund's), `budget_amend` | `org.manage_budget` | governed, delegable | FY2027's lines drafted, then proposed as one budget → proposal |
| `budget_stage` | `org.manage_budget` | governed, delegable | Reserve 40,000 of Roads' capital line for the resurfacing tender; on award, commit 38,500 of it and release 1,500 (`reserve: -40000, commit: 38500`) |
| `budget_list` | `treasury.view` | read, delegable | Roads' FY2026 lines, each with planned, reserved, committed and actual |
| `budget_extend` | `org.manage_budget` | delegable | FY2027 opens: FY2026's adopted lines carry over as `extended`, fund by fund, for the funds with no extended, proposed or adopted line in FY2027 yet; `Conflict` when none is left |
| `allocation_rule_draft`, `allocation_rule_propose` | `org.manage_budget` | governed, delegable | Welfare share from 30% to 35% → proposal |
| `payroll_run` | `org.manage_budget` | governed, delegable | November salaries: 23 seats, 51,200 REALM |
| `loan_create` | `org.manage_budget` | governed, delegable | Borrow 500,000 REALM from Bank A over 10 years → proposal |
| `loan_repay` | `org.manage_budget` | delegable | Finance records a repayment of 80,000 REALM |
| `loan_list` | `treasury.view` | read, delegable | The realm's loans and what is outstanding |
| `report_issue` (with the issuer's `adjustments`, for a report in terms the ledger doesn't keep) | `treasury.manage` | signing, confirm | Finance issues the FY2025 statements |
| `tax_policy_draft`, `tax_policy_propose` | `tax.manage` | governed, delegable | `TAX-POLICY-4` drafted with `property_tax` at 0.5 %, then proposed → realm-wide vote; legislation checks each entry at the draft and again at the proposal |
| `tax_assess` | `tax.assess` | delegable | Annual run: 1,180 property-tax invoices |
| `tax_declare` | `tax.declare` | delegable | `{organization: "clinic-b", period: "2026-Q3", base: "revenue", amount: 182000}` → `INV-412` |
| `payment_account_add`, `payment_account_remove` | `self.data_manage` | confirm | Bob adds his ckBTC address; prepared by a delegate, it waits for his approval |
| `token_force_transfer`, `token_freeze` | `token.force_transfer`, `token.freeze` | signing, governed, confirm | Court-ordered restitution: 500 REALM from Mallory to Alice; freeze Mallory's account meanwhile |

A tax policy's `taxes` are typed entries, so legislation can check them one by one: a rule on
`tax_policy_propose` ranges over the entries of the saved policy the id names, one check per entry with
the entry's fields as its facts, and the same rules run when a draft is saved with `tax_policy_draft`
([layered codex §3.2](codex.md#32-four-mechanisms)). An entry's `rate` or `amount` is
what it charges when no codex computes it; `tax_assess` asks the active codex for each taxpayer's
amount where it has one to give. A progressive tax, a rate per bracket of the base, is the exact total
over all its brackets, rounded once by the money rule, an exact half away from zero, to the nearest
cent, a multiple of 10^(decimals − 2) smallest units
([layered codex §3.3](codex.md#33-the-fact-schema-units-rates-money-and-periods));
rounding each bracket's share would move the total by up to half a cent per bracket. On a base of
150.08 under 10 % up to 100.05 and 20 % above, the shares are 10.005 and 10.006 and the tax is 20.01,
the total 20.011 rounded once; bracket by bracket it would be 10.01 + 10.01 = 20.02.
[`conformance/src/money.js`](../conformance/src/money.js) is this rule as code, with the example as
its test.

A budget is proposed per period: `budget_propose` takes the draft lines of the period together, with
`years` when the plan covers more than one period, and legislation reads the totals of the lines it
proposes, `revenue` and `expense`, the sums of `planned` over their `revenue` and `expense` lines, as
facts of the call (derived facts, [layered codex §3.3](codex.md#33-the-fact-schema-units-rates-money-and-periods));
legislation tells the two forms apart by `fund`. With a `fund`, it proposes that fund's draft lines of
the period, and the fund's owner governs it, under its own policy; without one, every fund's, and the
root governs it, as it governs `loan_create`: the realm's budget as a whole and its borrowing are the
realm's. Creating an owned record is governed by its owner: `fund_create` by the department named, the
root when none is. The lines are fixed when the proposal is filed, by the governed call or by any
proposal that carries it: they are `proposed`, with the proposal, a later `budget_propose` takes only
the `draft` lines left (`Conflict` when there are none), and the execution adopts exactly that
proposal's lines. A proposal that ends without adopting them (`rejected`, `expired`, `withdrawn`,
stopped, or `failed`) returns them to `draft`, with no proposal, so the fund's budget can be proposed
again. When a period opens, `budget_extend` copies, for each fund with no `extended`, `proposed` or
`adopted` line in it yet, the lines of that fund that stood at the previous period's end, `adopted`,
`extended` or `closed` with it, into the new period as `extended`, without a vote, so a budget
extended twice carries over; they hold until an adopted budget of that fund replaces them, which
makes them `amended`, so a category the adopted budget dropped does not come back at the next
extension; a later adopted line of the same fund, period and category amends the earlier one too,
within one adoption as well, where the line drafted later stands, and the spending booked against
the earlier one carries over, so one line stands per fund, period and category and the next
extension carries the newest; adopting one fund's lines neither blocks nor replaces another fund's
extensions; when no fund is left to extend it is refused with `Conflict`, while `draft` lines stand
in no way. An adopted budget is exhaustive for its fund: once a fund has an adopted budget for a
period, a `transfer_create` from it in that period names a category with an adopted `expense` line,
and any other is refused with `Conflict`; a transfer with no category counts as the category
`transfer`; a fund with only extended lines, or with none, spends as before. The ledger's fee for a
payment is exempt: the fee's ledger entry, which the GOS books itself in the category `ledger_fee`,
is a mechanical cost of the payment, not a spending decision. So is a sweep (§10), which moves the
realm's money from a quarter to its capital: it is neither revenue nor spending, and its entries are
booked by the GOS in the category `sweep`, kind `equity`, on both sides. `ledger_fee` and `sweep`
are reserved: a `transfer_create` or `budget_draft` naming either is refused with
`InvalidArgument`, budget or not, so no proposal or extension carries one; every other category, an
uncategorised transfer and payroll included, needs a line once the fund's budget is adopted.
Within a fund and period a category is
either `revenue` or `expense`: a draft whose fund, period and category already have a line of the
other kind is refused with `InvalidArgument`, and `budget_extend` leaves out a line whose category
the new period already holds as the other kind. A `budget_propose` whose derived total, `revenue` or
`expense`, is out of Money's range is refused with `InvalidArgument`, like any other fact.

### Invariants

- I-FIN-1: Every transaction's ledger entries balance (Σ debit = Σ credit).
- I-FIN-2: Money moves out of a fund only through `transfer_create` under the fund owner's policy, or
  in a quarter's sweep to its capital under the capital's governed rules (I-FED-5).
- I-FIN-3: An invoice is `paid` only when the ledger shows the amount in its subaccount.
- I-FIN-4: Adopted budgets, allocation rules and tax policies are frozen; changes create a new version.
- I-FIN-5: A closed fiscal period accepts no new entries; corrections go into a restating report.
- I-FIN-6: The realm never moves a member's own funds, except a court-ordered `token_force_transfer` on a realm-issued token (signing, governed).
- I-FIN-7: An invoice has at least one item, and its items sum to its `amount`, which is never negative; a
  line joins only a `pending` invoice.
- I-FIN-8: `Treasury.debt_outstanding` is the sum of the active loans' `outstanding`; a repayment never
  exceeds a loan's.
- I-FIN-9: An adopted `expense` line's money is in four stages: `reserved`, set aside for a spending
  not yet committed; `committed`, promised to a third party and not yet charged; `actual`, charged; and
  its available credit, `planned - reserved - committed - actual`, which is never negative. Every other
  line holds nothing reserved or committed. `budget_stage`, governed by the owner of the line's fund,
  adds its `reserve` and `commit` to the line's reserved and committed money, a negative one releasing
  it; it is refused with `Conflict` when either would fall below zero or the available credit would,
  and with `InvalidArgument` when both are zero or the line is not an adopted expense line. Where the
  fund's adopted budget governs its spending (above), a `transfer_create` is charged to the line of its
  category when it is created, whether it is paid at once or `scheduled`: with `committed`, the line's
  committed money pays it, else its available credit does, and when that holds less than the
  transfer's amount the transfer is refused with `Conflict`, with a message that names the line and
  says by how much it is short. So no transfer takes a line above `planned`: spending without
  available credit is refused, not recorded. It is checked when the transfer is filed and again when
  it applies. A transfer that ends `cancelled` or `failed` gives back what it charged, to the stage it
  came from. Where no adopted budget governs the fund's spending, a transfer is charged to no line, as
  before, and its `committed` is recorded false. An adopted line that replaces an earlier one carries its reserved, committed and actual
  money, and is refused with `Conflict`, with the budget that adopts it, when they would take it above
  its `planned`; `budget_amend` never sets `planned` below what a line holds; `budget_extend` copies
  lines with nothing reserved or committed.
- I-FIN-10: A transfer created with a `due_at`, which must lie after the call (`InvalidArgument`), is
  `scheduled`: the realm owes it and no money moves. `transfer_pay` pays it, early or late, taking it
  to `sending` and on as any transfer; it is not governed, since the governed `transfer_create`
  decided the payment, and any status but `scheduled` is `Conflict`. `transfer_revert`, governed by the
  owner of the transfer's fund, cancels a scheduled transfer, which ends `cancelled`, unpaid. A
  transfer's `due_at` never moves. `transfer_list` lists the realm's transfers by fund and status, so
  its `scheduled` transfers and their due dates are what the realm owes and when.
- I-FIN-11: The payments on a contract never exceed its `value`. What has been paid on it is the sum of
  the amounts of the transfers that name it (`transfer_create`'s `contract`, kept as
  `Transfer.contract`), those that ended `failed` or `cancelled` excepted. A `scheduled` transfer is
  owed and counts, as it counts against a budget line (I-FIN-9), so a payment that falls due never
  takes the contract above its value. A `transfer_create` that names no such contract is `NotFound`;
  one in another `symbol` than the contract's is `InvalidArgument`, since the amounts cannot be
  compared; one that would take the payments above the value is `Conflict`, with a message that names
  the contract and says by how much the transfer is over. It is checked when the transfer is filed and
  again when it applies, so two proposals that together overpay cannot both execute. `contract_amend`
  meets the same sum from the other side: it never sets `value` below what has been paid (I-GOV-16).
  The realm counts only the transfers that name the contract: a payment made outside the realm, or
  filed without it, is not checked.
