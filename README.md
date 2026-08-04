# Customer Segmentation & Retention Analysis (RFM)

## Overview
RFM (Recency, Frequency, Monetary) segmentation on 2 years of online retail transaction data (Dec 2009 - Dec 2011). The goal was to identify customer segments based on purchase behavior, enabling targeted retention strategies for each group (Champions, Loyal, At Risk, Lost).

## Dataset
- **Source:** Online Retail II (UCI Machine Learning Repository)
- **Rows (after cleaning):** 802,713 transactions across 5,853 unique customers
- **Time Span:** December 2009 - December 2011 (2 years)
- **Countries:** UK-based retailer, international customers
- **Transaction Value:** £0.01 to £608,821 per customer (includes wholesale bulk orders)

### Data Cleaning Process
This was a non-trivial cleaning exercise — the raw dataset (~1.07M rows) had several realistic data-quality issues:

1. **File encoding & import:** CSV had UTF-8 BOM; MySQL's `LOAD DATA INFILE` required switching from `utf8mb4` to `latin1` charset to handle £ symbols and special characters in product descriptions.

2. **Secure file permissions:** MySQL's `secure_file_priv` restriction required moving files to the designated uploads directory before import; learned the importance of understanding database-level security constraints.

3. **Null Customer IDs:** ~29% of rows (157,388 rows) had missing customer IDs. **Decision:** Excluded from RFM calculation, since customer segmentation requires a customer identifier. These rows represent transactions that couldn't be tied to a customer.

4. **Non-product line items:** ~23% of rows (242,724 rows) were fees, adjustments, or test entries (POST, DOT, ADJUST, TEST001, BANK CHARGES, etc.). **Decision:** Excluded from all analysis, as these don't represent actual customer purchases.

5. **Returns (negative quantities):** ~2.2% of rows (17,934 rows) had negative quantities (customer refunds/cancellations). **Decision:** Excluded from RFM to measure *purchasing behavior*, not net revenue. This is a deliberate trade-off: RFM now reflects gross purchasing intent, not final net revenue retained.

   *Note: A refined analysis could build a parallel "net revenue RFM" to compare behavior-based vs financially-accurate segmentation.*

6. **Data type conversion:** InvoiceDate imported as text; converted to Date/Time in Power BI's Power Query with error handling to catch format mismatches.

**Final clean dataset: 802,713 rows across 5,853 customers**, ready for RFM analysis.

## Key Questions Asked

### RFM-Specific
1. For each customer, how many days since their last purchase? (Recency)
2. How many distinct orders has each customer placed? (Frequency)
3. How much total revenue has each customer generated? (Monetary)
4. Which customers are "Champions" (recent, frequent, high-spend) vs "At Risk" vs "Lost"?
5. What % of revenue comes from the top 10-20% of customers? (concentration/80-20 rule)

### Supporting Context
6. What are the best-selling products by quantity and revenue?
7. Is there seasonality in sales across the 2-year period?
8. How does sales break down by country/region?

## Methodology

### SQL Layer (Advanced)
- Used **CTEs (Common Table Expressions)** to cleanly separate Recency, Frequency, Monetary calculations before joining
- Used **window functions (`NTILE(4)`)** for quartile-based scoring (Recency ranked ascending, Frequency/Monetary descending)
- Wrote two complete segmentation approaches:
  1. **NTILE-based (relative scoring):** Assigns each customer to a quartile per metric, then sums scores (3-12 range) into segment labels
  2. **Fixed-threshold (absolute scoring):** Recency ≤30 days, Frequency ≥10 orders, Monetary ≥£2000 for "Champion"; other thresholds for other segments

### Comparison of Segmentation Approaches
| Segment | NTILE | Fixed Rules |
|---------|-------|-------------|
| Champion | 1,184 (20%) | 611 (10%) |
| Loyal | 1,729 (30%) | 1,563 (27%) |
| At Risk | 1,184 (20%) | 1,115 (19%) |
| Lost | 1,756 (30%) | 2,564 (44%) |

**Insight:** NTILE always allocates exactly 25% to the "best" bucket per metric, regardless of business reality. Fixed thresholds enforce absolute business standards, resulting in a stricter, more selective Champion group and larger Lost segment. For this project, **fixed thresholds were chosen for the final dashboard** as they align with concrete business criteria ("truly" recent, "truly" high-value).

### Excel Layer
- Practiced advanced cleaning techniques: Remove Duplicates, Text-to-Columns, Conditional Formatting for outlier detection
- Learned real constraint: Go To Special > Blanks applies across *entire selection*, not per-column, causing unintended over-deletion; reinforced why SQL is safer for large-scale cleaning

### Power BI Layer
- **Data connection:** Direct MySQL connection to `retail_final` table (cleaned, row-level)
- **Calculated table:** Built `RFM_Table` using `SUMMARIZE()` DAX function to group transactions into one row per customer
  - Recency: `DATEDIFF()` from each customer's max purchase date to reference date (Dec 9, 2011)
  - Frequency: `DISTINCTCOUNT()` of distinct invoices
  - Monetary: `SUMX()` to multiply price×quantity per row, then sum per customer
- **Segmentation column:** Used nested `IF()` logic in DAX to apply fixed-threshold rules (same logic as SQL CASE WHEN)
- **Dashboard:** Built 6 visuals:
  1. Donut chart: Segment distribution (Champions 20%, Loyal 30%, At Risk 20%, Lost 30%)
  2. 100% stacked bar: Segment breakdown by country (top markets shown)
  3. Line chart: Total Revenue by country (geographic concentration)
  4. Clustered bar: Avg Frequency by segment (Champions average 26+ orders; Lost <1)
  5. Clustered bar: Avg Recency by segment (Champions 0-5 days; Lost 300+ days)
  6. Clustered bar: Avg Monetary by segment (Champions £15K+; Lost <£100)
- **KPI cards:** Total Customers, Total Revenue, Avg Order Value, plus segment slicer for drill-down

## Key Insights

1. **Strong customer concentration.** Top 20% of customers (by revenue) account for ~70% of total revenue; top 50% account for ~95%. This is classic 80/20 rule — retention of Champions and Loyal segments is disproportionately valuable.

2. **Champions are rare but critical.** Only 20% of customers (1,184) are Champions; they drive £15K+ average revenue each. Losing a Champion is expensive.

3. **At Risk segment is large and actionable.** 20% of customers (1,184) haven't purchased recently but historically bought frequently — these are win-back targets. They lapsed, they didn't churn permanently; re-engagement is viable.

4. **Lost segment (30%) is vast and likely unrecoverable.** 1,756 customers with no purchase in 90+ days and low historical frequency. Cost of re-acquiring likely exceeds their lifetime value.

5. **Geographic concentration.** United Kingdom represents >85% of revenue; next highest is EIRE (Ireland) at ~4%. International expansion or UK-focused retention strategy makes sense depending on business goals.

6. **Outlier: Customer 12346.** Purchased 74,215 units in a single transaction (~£77K), but this appears to be a bulk order later fully returned (negative quantity rows excluded). Real Monetary value for this customer is likely £0 after return. Worth flagging in refined analysis.

## Trade-offs & Limitations

- **Gross vs Net Revenue:** RFM reflects purchasing behavior (returns excluded), not actual revenue retained. A refined analysis could build a parallel "net revenue RFM" for financial accuracy.
- **Time-period bias:** Recency is relative to Dec 9, 2011 (last day in dataset). A customer inactive since Nov 2011 is treated differently than the same customer today (15+ years later). Results are only valid within the 2009-2011 context.
- **No customer demographic data:** Can't segment by age, geography, product category preference, etc. RFM alone is powerful but incomplete.
- **Seasonality not explored:** 2-year span could mask seasonal patterns (holiday vs non-holiday purchasing behavior).

## Tools & Skills Demonstrated
- **SQL:** CTEs, window functions (NTILE, MAX, DISTINCTCOUNT), aggregate functions, CASE WHEN logic, DATEDIFF for date arithmetic
- **Excel:** Remove Duplicates, Text-to-Columns, Conditional Formatting, outlier detection
- **Power BI:** DAX (SUMMARIZE, SUMX, DATEDIFF, DISTINCTCOUNT), calculated tables, nested IF logic, multi-metric dashboard design, KPI cards
- **Data Cleaning:** Handling mixed formats, encoding issues, null values, non-product entries, understanding business logic (returns vs purchases)
- **Analytics:** RFM methodology, trade-offs between relative (NTILE) and absolute (fixed-threshold) scoring, customer segmentation strategy

------------------------------------------------------------------------------------------------------------------------------------------------------------
