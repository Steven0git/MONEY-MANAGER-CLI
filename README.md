# 💰 MONEY-MANAGER-CLI

A lightweight, privacy-focused CLI personal finance manager built with Bash and SQLite3. Supports multi-account, multi-currency, budgeting, and monthly logs.

---

## ✨ Features

- **Multi-Account & Multi-Currency:** Manage various accounts (`wallet`, `bank`, `etc`) in **IDR**, **USD**, and **CNY** with automatic balance tracking.
- **Transaction Tracking:** Record income, expenses, and transfers with custom titles, descriptions, and automatic timestamps.
- **Expense Budgeting:** Set and monitor monthly spending targets per expense category.
- **Financial Health Summary:** Automatically calculates your total balance, transaction averages, highest expense category, and determines if you are **Under Control** or **Over Expense**.
- **Monthly Logs & MoM Analysis:** View monthly summaries (Sum Income, Sum Expense, Net Sum) alongside Month-over-Month (MoM) expense growth/decline percentages.
- **Transaction Management:** View recent transaction history and safely delete records with automatic account balance reversals.
- **Debt & Receivable Tracker:** Keep track of people who owe you or money you owe, with due dates and payment statuses.
- **Exchange Rates & Conversion:** Built-in currency converter and adjustable exchange rates.
- **Export & Backup:** Export your transactions to a `.csv` file or create a secure backup of your SQLite database (`.db`).

---

## 🛠️ Prerequisites

Ensure you have the following installed on your system (Linux, macOS, or **Termux** on Android):
- **Bash** (v4+)
- **SQLite3**
- **Awk** & **Bc**

---

## 🚀 Installation & Usage

1. **Clone or download** this repository:
   ```bash
   git clone [https://github.com/your-username/MONEY-MANAGER-CLI.git](https://github.com/your-username/MONEY-MANAGER-CLI.git)
   cd MONEY-MANAGER-CLI

 * Grant execution permissions to the script:
   chmod +x finance.sh

 * Run the application:
   ./finance.sh

🧭 Menu Navigation Overview
=== PERSONAL FINANCE MANAGER ===

1. Manage Accounts (Wallet, Bank, ETC & Currency)
2. Manage Categories (Income, Expense)
3. Record Transaction (Income, Expense, Transfer)
4. Budget Targets (Expense Budgeting)
5. Financial Summary & Health Status
6. Monthly Transaction Logs (Sum, Net, & MoM)
7. Transaction Management (Edit & Delete)
8. Debts & Receivables (Debt Tracker)
9. Exchange Rates & Currency Conversion
10. Export & Backup Data
11. Exit

📱 Termux Friendly
Designed with responsiveness and clean tab formatting (\t), this application runs smoothly inside mobile terminal emulators like Termux on Android as well as any standard desktop terminal.

