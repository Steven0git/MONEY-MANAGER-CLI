#!/usr/bin/env bash

DB_FILE="finance.db"

# --- COLOR & TEXT DESIGN (ANSI) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if sqlite3 is installed
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}Error: sqlite3 is not installed. Please install sqlite3 first.${NC}"
    exit 1
fi

# --- CURRENCY FORMAT FUNCTION (72000 -> 72.000,00) ---
format_money() {
    local amount=$1
    local currency=$2
    
    if [ -z "$amount" ]; then amount=0; fi

    local formatted
    formatted=$(awk -v n="$amount" 'BEGIN {
        str = sprintf("%.2f", n)
        split(str, parts, ".")
        int_part = parts[1]
        dec_part = parts[2]
        
        sign = ""
        if (int_part ~ /^-/) {
            sign = "-"
            sub(/^-/, "", int_part)
        }
        
        l = length(int_part)
        res = ""
        for (i = l; i >= 1; i--) {
            res = substr(int_part, i, 1) res
            if ((l - i) % 3 == 2 && i > 1) {
                res = "." res
            }
        }
        print sign res "," dec_part
    }')

    case "$currency" in
        IDR) echo "Rp $formatted" ;;
        USD) echo "$ $formatted" ;;
        CNY) echo "¥ $formatted" ;;
        *) echo "$currency $formatted" ;;
    esac
}

# Initialize Database Schema & Additional Tables
init_db() {
    sqlite3 "$DB_FILE" <<EOF
    CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT CHECK(type IN ('wallet', 'bank', 'etc')) NOT NULL,
        currency TEXT CHECK(currency IN ('IDR', 'USD', 'CNY')) DEFAULT 'IDR',
        balance REAL DEFAULT 0.0
    );

    CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT CHECK(type IN ('income', 'expense')) NOT NULL
    );

    CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        target_amount REAL NOT NULL,
        period TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id)
    );

    CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT CHECK(type IN ('income', 'expense', 'transfer')) NOT NULL,
        amount REAL NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        account_id INTEGER,
        to_account_id INTEGER,
        category_id INTEGER,
        FOREIGN KEY(account_id) REFERENCES accounts(id),
        FOREIGN KEY(to_account_id) REFERENCES accounts(id),
        FOREIGN KEY(category_id) REFERENCES categories(id)
    );

    CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        type TEXT CHECK(type IN ('debt', 'receivable')) NOT NULL,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'IDR',
        due_date TEXT,
        status TEXT CHECK(status IN ('unpaid', 'paid')) DEFAULT 'unpaid',
        description TEXT
    );

    CREATE TABLE IF NOT EXISTS exchange_rates (
        currency TEXT PRIMARY KEY,
        rate_to_idr REAL NOT NULL
    );
EOF

    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO exchange_rates (currency, rate_to_idr) VALUES ('IDR', 1.0);"
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO exchange_rates (currency, rate_to_idr) VALUES ('USD', 16000.0);"
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO exchange_rates (currency, rate_to_idr) VALUES ('CNY', 2200.0);"
}

init_db

# --- 1. ACCOUNTS FEATURE ---
manage_accounts() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== ACCOUNTS & WALLET MANAGEMENT ===${NC}\n"
        echo -e "\t1. View Accounts & Balances"
        echo -e "\t2. Add New Account"
        echo -e "\t3. Return to Main Menu"
        echo -ne "\n\tChoose option [1-3]: "
        read -r choice

        case $choice in
            1)
                echo -e "\n\t\t\t${BOLD}--- Account List & Balances ---${NC}\n"
                printf "\t%-4s \t%-22s \t%-10s \t%-10s \t%-22s\n" "ID" "Account Name" "Type" "Currency" "Balance"
                printf "\t----------------------------------------------------------------------------------------\n"
                
                sqlite3 "$DB_FILE" "SELECT id, name, type, currency, balance FROM accounts;" | while IFS='|' read -r id name type currency balance; do
                    f_bal=$(format_money "$balance" "$currency")
                    printf "\t%-4s \t%-22s \t%-10s \t%-10s \t%-22s\n" "$id" "$name" "$type" "$currency" "$f_bal"
                done
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            2)
                echo -e "\n\t\t\t${BOLD}--- Add New Account ---${NC}\n"
                echo -ne "\tAccount Name (e.g., Bank BCA, Pocket): "
                read -r name
                
                echo -e "\n\tSelect Account Type:"
                echo -e "\t1. wallet"
                echo -e "\t2. bank"
                echo -e "\t3. etc (E-Wallet/Other)"
                echo -ne "\tType choice [1-3]: "
                read -r t_choice
                case $t_choice in
                    1) type="wallet" ;;
                    2) type="bank" ;;
                    3) type="etc" ;;
                    *) type="wallet" ;;
                esac

                echo -e "\n\tSelect Currency:"
                echo -e "\t1. IDR (Indonesian Rupiah)"
                echo -e "\t2. USD (US Dollar)"
                echo -e "\t3. CNY (Chinese Yuan)"
                echo -ne "\tCurrency choice [1-3]: "
                read -r c_choice
                case $c_choice in
                    1) currency="IDR" ;;
                    2) currency="USD" ;;
                    3) currency="CNY" ;;
                    *) currency="IDR" ;;
                esac

                echo -ne "\tInitial Balance (default 0): "
                read -r init_bal
                init_bal=${init_bal:-0.0}

                sqlite3 "$DB_FILE" "INSERT INTO accounts (name, type, currency, balance) VALUES ('$name', '$type', '$currency', $init_bal);"
                echo -e "\n\t${GREEN}✔ Account successfully added!${NC}"
                sleep 1
                ;;
            3)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 2. CATEGORIES FEATURE ---
manage_categories() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== CATEGORY MANAGEMENT ===${NC}\n"
        echo -e "\t1. View Category List"
        echo -e "\t2. Add New Category"
        echo -e "\t3. Return to Main Menu"
        echo -ne "\n\tChoose option [1-3]: "
        read -r choice

        case $choice in
            1)
                echo -e "\n\t\t\t${BOLD}--- Category List ---${NC}\n"
                echo -e "\tID\tCategory Name\t\tType"
                echo -e "\t------------------------------------------------"
                sqlite3 "$DB_FILE" "SELECT id, name, type FROM categories ORDER BY type, name;" | while IFS='|' read -r id name type; do
                    echo -e "\t$id\t$name\t\t$type"
                done
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            2)
                echo -e "\n\t\t\t${BOLD}--- Add New Category ---${NC}\n"
                echo -ne "\tCategory Name: "
                read -r name
                echo -e "\n\tSelect Category Type:"
                echo -e "\t1. income"
                echo -e "\t2. expense"
                echo -ne "\tType choice [1-2]: "
                read -r t_choice
                case $t_choice in
                    1) type="income" ;;
                    2) type="expense" ;;
                    *) type="expense" ;;
                esac

                sqlite3 "$DB_FILE" "INSERT INTO categories (name, type) VALUES ('$name', '$type');"
                echo -e "\n\t${GREEN}✔ Category successfully added!${NC}"
                sleep 1
                ;;
            3)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 3. TRANSACTIONS FEATURE ---
add_transaction() {
    clear
    echo -e "\n\t\t\t${CYAN}=== ADD TRANSACTION ===${NC}\n"
    echo -e "\tSelect Transaction Type:"
    echo -e "\t1. Income"
    echo -e "\t2. Expense"
    echo -e "\t3. Transfer Between Accounts"
    echo -ne "\tChoice [1-3]: "
    read -r t_type_choice

    case $t_type_choice in
        1) type="income" ;;
        2) type="expense" ;;
        3) type="transfer" ;;
        *) echo -e "\n\t${RED}Invalid option.${NC}"; sleep 1; return ;;
    esac

    echo -ne "\tTITLE: "
    read -r title
    echo -ne "\tVALUE: "
    read -r amount
    echo -ne "\tDESCRIPTION (Optional): "
    read -r description
    echo -ne "\tDATE (YYYY-MM-DD HH:MM:SS, leave blank for current): "
    read -r date

    if [ -z "$date" ]; then
        date=$(date '+%Y-%m-%d %H:%M:%S')
    fi

    echo -e "\n\t\t${BOLD}--- SELECT ACCOUNT ---${NC}"
    sqlite3 -header -column "$DB_FILE" "SELECT id, name, currency, balance FROM accounts;"
    echo -ne "\tSOURCE ACCOUNT ID: "
    read -r account_id

    if [ "$type" == "transfer" ]; then
        echo -ne "\tDESTINATION ACCOUNT ID: "
        read -r to_account_id
        
        sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance - $amount WHERE id = $account_id;"
        sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance + $amount WHERE id = $to_account_id;"
        
        sqlite3 "$DB_FILE" "INSERT INTO transactions (type, amount, title, description, date, account_id, to_account_id) VALUES ('transfer', $amount, '$title', '$description', '$date', $account_id, $to_account_id);"
        echo -e "\n\t${GREEN}✔ Transfer successfully recorded!${NC}"
    else
        echo -e "\n\t\t${BOLD}--- SELECT CATEGORY ($type) ---${NC}"
        sqlite3 -header -column "$DB_FILE" "SELECT id, name FROM categories WHERE type='$type';"
        echo -ne "\tCATEGORY ID: "
        read -r category_id

        if [ "$type" == "income" ]; then
            sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance + $amount WHERE id = $account_id;"
        elif [ "$type" == "expense" ]; then
            sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance - $amount WHERE id = $account_id;"
        fi

        sqlite3 "$DB_FILE" "INSERT INTO transactions (type, amount, title, description, date, account_id, category_id) VALUES ('$type', $amount, '$title', '$description', '$date', $account_id, $category_id);"
        echo -e "\n\t${GREEN}✔ $type transaction successfully recorded!${NC}"
    fi
    sleep 1.5
}

# --- 4. BUDGETING FEATURE ---
manage_budget() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== BUDGET TARGET MANAGEMENT ===${NC}\n"
        echo -e "\t1. View Current Month Budget Status"
        echo -e "\t2. Set / Add Category Budget Target"
        echo -e "\t3. Return to Main Menu"
        echo -ne "\n\tChoose option [1-3]: "
        read -r choice

        current_period=$(date '+%Y-%m')

        case $choice in
            1)
                echo -e "\n\t\t\t${BOLD}--- Expense Budget Status ($current_period) ---${NC}\n"
                echo -e "\tCategory\t\tTarget\t\tSpent\t\tRemaining"
                echo -e "\t----------------------------------------------------------------"
                sqlite3 "$DB_FILE" "
                    SELECT 
                        c.name,
                        b.target_amount,
                        COALESCE(SUM(t.amount), 0) AS terpakai,
                        (b.target_amount - COALESCE(SUM(t.amount), 0)) AS sisa
                    FROM budgets b
                    JOIN categories c ON b.category_id = c.id
                    LEFT JOIN transactions t ON t.category_id = c.id 
                        AND t.type = 'expense' 
                        AND strftime('%Y-%m', t.date) = b.period
                    WHERE b.period = '$current_period'
                    GROUP BY b.id;
                " | while IFS='|' read -r cat target terpakai sisa; do
                    f_target=$(format_money "$target" "IDR")
                    f_terpakai=$(format_money "$terpakai" "IDR")
                    f_sisa=$(format_money "$sisa" "IDR")
                    echo -e "\t$cat\t\t$f_target\t$f_terpakai\t$f_sisa"
                done
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            2)
                echo -e "\n\t\t\t${BOLD}--- Set Expense Budget Target ---${NC}\n"
                sqlite3 -header -column "$DB_FILE" "SELECT id, name FROM categories WHERE type='expense';"
                echo -ne "\tExpense Category ID: "
                read -r cat_id
                echo -ne "\tTarget Budget Amount: "
                read -r target_amt
                echo -ne "\tPeriod (YYYY-MM, leave blank for [$current_period]): "
                read -r period
                period=${period:-$current_period}

                exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM budgets WHERE category_id=$cat_id AND period='$period';")
                if [ "$exists" -gt 0 ]; then
                    sqlite3 "$DB_FILE" "UPDATE budgets SET target_amount=$target_amt WHERE category_id=$cat_id AND period='$period';"
                else
                    sqlite3 "$DB_FILE" "INSERT INTO budgets (category_id, target_amount, period) VALUES ($cat_id, $target_amt, '$period');"
                fi
                echo -e "\n\t${GREEN}✔ Budget successfully saved!${NC}"
                sleep 1
                ;;
            3)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 5. SUMMARY FEATURE ---
show_summary() {
    clear
    echo -e "\n\t\t\t${CYAN}=== SUMMARY & FINANCIAL HEALTH ===${NC}\n"

    echo -e "\t${BOLD}💰 Total Balance per Currency:${NC}"
    sqlite3 "$DB_FILE" "SELECT currency, SUM(balance) FROM accounts GROUP BY currency;" | while IFS='|' read -r curr total; do
        f_total=$(format_money "$total" "$curr")
        echo -e "\t   • $curr : ${GREEN}$f_total${NC}"
    done

    avg_inc=$(sqlite3 "$DB_FILE" "SELECT COALESCE(AVG(amount), 0) FROM transactions WHERE type='income';")
    avg_exp=$(sqlite3 "$DB_FILE" "SELECT COALESCE(AVG(amount), 0) FROM transactions WHERE type='expense';")
    
    f_avg_inc=$(format_money "$avg_inc" "IDR")
    f_avg_exp=$(format_money "$avg_exp" "IDR")

    echo -e "\n\t${BOLD}📈 Transaction Statistics:${NC}"
    echo -e "\t   • Average Income    : ${GREEN}$f_avg_inc${NC}"
    echo -e "\t   • Average Expense   : ${RED}$f_avg_exp${NC}"

    echo -e "\n\t${BOLD}🔥 Highest Expense Category:${NC}"
    sqlite3 "$DB_FILE" "
        SELECT c.name, SUM(t.amount) AS total_exp
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE t.type = 'expense'
        GROUP BY t.category_id
        ORDER BY total_exp DESC
        LIMIT 1;
    " | while IFS='|' read -r c_name c_total; do
        f_c_total=$(format_money "$c_total" "IDR")
        echo -e "\t   • $c_name (${RED}$f_c_total${NC})"
    done

    current_month=$(date '+%Y-%m')
    m_inc=$(sqlite3 "$DB_FILE" "SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type='income' AND strftime('%Y-%m', date) = '$current_month';")
    m_exp=$(sqlite3 "$DB_FILE" "SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type='expense' AND strftime('%Y-%m', date) = '$current_month';")

    f_m_inc=$(format_money "$m_inc" "IDR")
    f_m_exp=$(format_money "$m_exp" "IDR")

    echo -e "\n\t${BOLD}📊 Current Month Financial Status ($current_month):${NC}"
    echo -e "\t   • Income This Month   : $f_m_inc"
    echo -e "\t   • Expense This Month  : $f_m_exp"
    
    echo -ne "\t   • Financial Status    : "
    if (( $(echo "$m_exp > $m_inc" | bc -l 2>/dev/null || awk "BEGIN {print ($m_exp > $m_inc)?1:0}") )); then
        echo -e "${RED}${BOLD}⚠ OVER EXPENSE (Expense > Income)${NC}"
    else
        echo -e "${GREEN}${BOLD}✔ UNDER CONTROL (Finances are Secure)${NC}"
    fi

    echo -e "\n\tPress [Enter] to return to menu..."
    read -r
}

# --- 6. MONTHLY TRANSACTION LOGS FEATURE ---
show_transaction_logs() {
    clear
    echo -e "\n\t\t\t${CYAN}=== MONTHLY TRANSACTION LOGS ===${NC}\n"

    periods=$(sqlite3 "$DB_FILE" "SELECT DISTINCT strftime('%Y-%m', date) FROM transactions ORDER BY strftime('%Y-%m', date) ASC;")

    if [ -z "$periods" ]; then
        echo -e "\tNo transaction data recorded yet."
        echo -e "\n\tPress [Enter] to return..."
        read -r
        return
    fi

    prev_exp=0

    while IFS= read -r period; do
        if [ -z "$period" ]; then continue; fi

        year=$(echo "$period" | cut -d'-' -f1)
        month_num=$(echo "$period" | cut -d'-' -f2)

        case "$month_num" in
            01) m_name="January" ;;
            02) m_name="February" ;;
            03) m_name="March" ;;
            04) m_name="April" ;;
            05) m_name="May" ;;
            06) m_name="June" ;;
            07) m_name="July" ;;
            08) m_name="August" ;;
            09) m_name="September" ;;
            10) m_name="October" ;;
            11) m_name="November" ;;
            12) m_name="December" ;;
            *) m_name="$month_num" ;;
        esac

        display_period="$m_name $year"

        read inc exp < <(sqlite3 "$DB_FILE" "
            SELECT 
                COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0),
                COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
            FROM transactions 
            WHERE strftime('%Y-%m', date) = '$period';
        " | tr '|' ' ')

        net=$(awk -v i="$inc" -v e="$exp" 'BEGIN {print i - e}')
        diff_exp=$(awk -v curr="$exp" -v prev="$prev_exp" 'BEGIN {print curr - prev}')

        if (( $(echo "$prev_exp > 0" | awk '{print ($1>0)?1:0}') )); then
            pct_exp=$(awk -v diff="$diff_exp" -v prev="$prev_exp" 'BEGIN {printf "%.2f", (diff / prev) * 100}')
        else
            if (( $(echo "$exp > 0" | awk '{print ($1>0)?1:0}') )); then
                pct_exp="100.00"
            else
                pct_exp="0.00"
            fi
        fi

        f_inc=$(format_money "$inc" "IDR")
        f_exp=$(format_money "$exp" "IDR")
        f_net=$(format_money "$net" "IDR")

        formatted_diff_str=$(awk -v d="$diff_exp" -v p="$pct_exp" 'BEGIN {
            abs_d = d < 0 ? -d : d
            str = sprintf("%.2f", abs_d)
            split(str, parts, ".")
            int_p = parts[1]; dec_p = parts[2]
            l = length(int_p); res = ""
            for (i = l; i >= 1; i--) {
                res = substr(int_p, i, 1) res
                if ((l - i) % 3 == 2 && i > 1) res = "." res
            }
            formatted_num = res "," dec_p
            
            if (d < 0) {
                print "(-" formatted_num ")(- " p "%)"
            } else if (d > 0) {
                print "(+" formatted_num ") (+" p "%)"
            } else {
                print "Rp 0,00 (0%)"
            }
        }')

        if [ "$(echo "$prev_exp == 0" | awk "BEGIN {print ($prev_exp==0)?1:0}")" -eq 1 ]; then
            change_display="First Month (Baseline)"
        else
            change_display="$formatted_diff_str"
        fi

        # Monthly Summary Box
        echo -e "\t┌────────────────────────────────────────────────────────┐"
        echo -e "\t│ Period         : ${BOLD}$display_period${NC}"
        echo -e "\t├────────────────────────────────────────────────────────┤"
        echo -e "\t│ Sum Income     : ${GREEN}$f_inc${NC}"
        echo -e "\t│ Sum Expense    : ${RED}$f_exp${NC}"
        echo -e "\t│ Net Sum        : ${CYAN}$f_net${NC}"
        echo -e "\t│ Expense Change : $change_display"
        echo -e "\t└────────────────────────────────────────────────────────┘\n"

        prev_exp=$exp
    done <<< "$periods"

    echo -ne "\tPress [Enter] to return..."
    read -r
}

# --- 7. TRANSACTION MANAGEMENT (EDIT & DELETE) ---
manage_transactions() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== TRANSACTION MANAGEMENT (DELETE) ===${NC}\n"
        echo -e "\t1. View Recent Transactions"
        echo -e "\t2. Delete Transaction by ID (Account Balance Auto-Adjusted)"
        echo -e "\t3. Return to Main Menu"
        echo -ne "\n\tChoose option [1-3]: "
        read -r choice

        case $choice in
            1)
                echo -e "\n\t\t\t${BOLD}--- Last 20 Transactions ---${NC}\n"
                printf "\t%-4s \t%-10s \t%-12s \t%-18s \t%-15s\n" "ID" "Type" "Date" "Title" "Amount"
                printf "\t---------------------------------------------------------------------------------\n"
                sqlite3 "$DB_FILE" "SELECT id, type, date, title, amount FROM transactions ORDER BY date DESC LIMIT 20;" | while IFS='|' read -r id type date title amount; do
                    f_amt=$(format_money "$amount" "IDR")
                    printf "\t%-4s \t%-10s \t%-12s \t%-18s \t%-15s\n" "$id" "$type" "$date" "$title" "$f_amt"
                done
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            2)
                echo -e "\n\t\t\t${BOLD}--- Delete Transaction ---${NC}\n"
                echo -ne "\tEnter Transaction ID to delete: "
                read -r tid

                t_data=$(sqlite3 "$DB_FILE" "SELECT type, amount, account_id, to_account_id FROM transactions WHERE id=$tid;")
                if [ -z "$t_data" ]; then
                    echo -e "\n\t${RED}❌ Transaction with that ID was not found.${NC}"
                    sleep 1.5
                    continue
                fi

                t_type=$(echo "$t_data" | cut -d'|' -f1)
                t_amt=$(echo "$t_data" | cut -d'|' -f2)
                t_acc=$(echo "$t_data" | cut -d'|' -f3)
                t_to_acc=$(echo "$t_data" | cut -d'|' -f4)

                if [ "$t_type" == "income" ]; then
                    sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance - $t_amt WHERE id=$t_acc;"
                elif [ "$t_type" == "expense" ]; then
                    sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance + $t_amt WHERE id=$t_acc;"
                elif [ "$t_type" == "transfer" ]; then
                    sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance + $t_amt WHERE id=$t_acc;"
                    sqlite3 "$DB_FILE" "UPDATE accounts SET balance = balance - $t_amt WHERE id=$t_to_acc;"
                fi

                sqlite3 "$DB_FILE" "DELETE FROM transactions WHERE id=$tid;"
                echo -e "\n\t${GREEN}✔ Transaction successfully deleted and account balance adjusted!${NC}"
                sleep 1.5
                ;;
            3)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 8. DEBTS & RECEIVABLES TRACKER ---
manage_debts() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== DEBTS & RECEIVABLES TRACKER ===${NC}\n"
        echo -e "\t1. View Debts & Receivables List"
        echo -e "\t2. Add New Record"
        echo -e "\t3. Update Status (Mark as Paid / Unpaid)"
        echo -e "\t4. Delete Record"
        echo -e "\t5. Return to Main Menu"
        echo -ne "\n\tChoose option [1-5]: "
        read -r choice

        case $choice in
            1)
                echo -e "\n\t\t\t${BOLD}--- Debts & Receivables List ---${NC}\n"
                printf "\t%-4s \t%-15s \t%-10s \t%-15s \t%-10s \t%-12s\n" "ID" "Name" "Type" "Amount" "Status" "Due Date"
                printf "\t--------------------------------------------------------------------------------------------------\n"
                sqlite3 "$DB_FILE" "SELECT id, person, type, amount, currency, status, due_date FROM debts;" | while IFS='|' read -r id person type amount currency status due_date; do
                    f_amt=$(format_money "$amount" "$currency")
                    printf "\t%-4s \t%-15s \t%-10s \t%-15s \t%-10s \t%-12s\n" "$id" "$person" "$type" "$f_amt" "$status" "$due_date"
                done
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            2)
                echo -e "\n\t\t\t${BOLD}--- Add New Debt / Receivable ---${NC}\n"
                echo -ne "\tPerson / Entity Name: "
                read -r person
                echo -e "\n\tType:"
                echo -e "\t1. debt (You borrowed money)"
                echo -e "\t2. receivable (Someone owes you money)"
                echo -ne "\tChoice [1-2]: "
                read -r d_type_c
                if [ "$d_type_c" == "1" ]; then dtype="debt"; else dtype="receivable"; fi

                echo -ne "\tAmount: "
                read -r amount
                echo -ne "\n\tCurrency (IDR/USD/CNY): "
                read -r currency
                currency=${currency:-IDR}
                echo -ne "\tDue Date (YYYY-MM-DD): "
                read -r due_date
                echo -ne "\tDescription (Optional): "
                read -r desc

                sqlite3 "$DB_FILE" "INSERT INTO debts (person, type, amount, currency, due_date, status, description) VALUES ('$person', '$dtype', $amount, '$currency', '$due_date', 'unpaid', '$desc');"
                echo -e "\n\t${GREEN}✔ Successfully recorded!${NC}"
                sleep 1
                ;;
            3)
                echo -e "\n\t\t\t${BOLD}--- Update Payment Status ---${NC}\n"
                echo -ne "\tEnter Record ID: "
                read -r did
                echo -e "\n\tSelect New Status:"
                echo -e "\t1. unpaid"
                echo -e "\t2. paid"
                echo -ne "\tChoice [1-2]: "
                read -r s_c
                if [ "$s_c" == "2" ]; then n_status="paid"; else n_status="unpaid"; fi

                sqlite3 "$DB_FILE" "UPDATE debts SET status='$n_status' WHERE id=$did;"
                echo -e "\n\t${GREEN}✔ Status successfully updated!${NC}"
                sleep 1
                ;;
            4)
                echo -e "\n\t\t\t${BOLD}--- Delete Record ---${NC}\n"
                echo -ne "\tEnter Record ID to delete: "
                read -r did
                sqlite3 "$DB_FILE" "DELETE FROM debts WHERE id=$did;"
                echo -e "\n\t${GREEN}✔ Successfully deleted!${NC}"
                sleep 1
                ;;
            5)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 9. EXCHANGE RATES & CONVERSION ---
manage_exchange() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== EXCHANGE RATES & CONVERSION ===${NC}\n"
        echo -e "\t1. View Exchange Rates (to IDR)"
        echo -e "\t2. Update Exchange Rate"
        echo -e "\t3. Simple Conversion Calculator"
        echo -e "\t4. Return to Main Menu"
        echo -ne "\n\tChoose option [1-4]: "
        read -r choice

        case $choice in
            1)
                echo -e "\n\t\t\t${BOLD}--- Exchange Rates List ---${NC}\n"
                printf "\t%-12s \t%-25s\n" "Currency" "Exchange Rate to IDR"
                printf "\t----------------------------------------------\n"
                sqlite3 "$DB_FILE" "SELECT currency, rate_to_idr FROM exchange_rates;" | while IFS='|' read -r curr rate; do
                    f_rate=$(format_money "$rate" "IDR")
                    printf "\t%-12s \t%-25s\n" "$curr" "$f_rate"
                done
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            2)
                echo -e "\n\t\t\t${BOLD}--- Update Exchange Rate ---${NC}\n"
                echo -ne "\n\tCurrency (USD / CNY): "
                read -r curr
                echo -ne "\tNew Rate to IDR (e.g., 16200): "
                read -r new_rate

                sqlite3 "$DB_FILE" "UPDATE exchange_rates SET rate_to_idr=$new_rate WHERE currency='$curr';"
                echo -e "\n\t${GREEN}✔ Exchange rate successfully updated!${NC}"
                sleep 1
                ;;
            3)
                echo -e "\n\t\t\t${BOLD}--- Conversion Calculator ---${NC}\n"
                echo -ne "\tEnter Amount: "
                read -r amt
                echo -ne "\tFrom Currency (IDR/USD/CNY): "
                read -r from_curr
                echo -ne "\tTo Currency (IDR/USD/CNY): "
                read -r to_curr

                rate_from=$(sqlite3 "$DB_FILE" "SELECT rate_to_idr FROM exchange_rates WHERE currency='$from_curr';")
                rate_to=$(sqlite3 "$DB_FILE" "SELECT rate_to_idr FROM exchange_rates WHERE currency='$to_curr';")

                if [ -z "$rate_from" ] || [ -z "$rate_to" ]; then
                    echo -e "\n\t${RED}❌ Unknown currency.${NC}"
                else
                    res=$(awk -v a="$amt" -v rf="$rate_from" -v rt="$rate_to" 'BEGIN {print (a * rf) / rt}')
                    f_res=$(format_money "$res" "$to_curr")
                    echo -e "\n\tConverted Amount: ${GREEN}$f_res${NC}"
                fi
                echo -e "\n\tPress [Enter] to continue..."
                read -r
                ;;
            4)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- 10. EXPORT & BACKUP FEATURE ---
manage_export() {
    while true; do
        clear
        echo -e "\n\t\t\t${CYAN}=== EXPORT & BACKUP DATA ===${NC}\n"
        echo -e "\t1. Export Transactions to CSV File"
        echo -e "\t2. Backup Database (.db)"
        echo -e "\t3. Return to Main Menu"
        echo -ne "\n\tChoose option [1-3]: "
        read -r choice

        case $choice in
            1)
                csv_file="transactions_export_$(date +%Y%m%d_%H%M%S).csv"
                sqlite3 -header -csv "$DB_FILE" "SELECT * FROM transactions;" > "$csv_file"
                echo -e "\n\t${GREEN}✔ Transactions successfully exported to file: $csv_file${NC}"
                sleep 1.5
                ;;
            2)
                backup_file="finance_backup_$(date +%Y%m%d_%H%M%S).db"
                cp "$DB_FILE" "$backup_file"
                echo -e "\n\t${GREEN}✔ Database successfully backed up to file: $backup_file${NC}"
                sleep 1.5
                ;;
            3)
                break
                ;;
            *)
                echo -e "\n\t${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# --- MAIN MENU ---
while true; do
    clear
    echo -e "\n\t\t\t${BLUE}=== PERSONAL FINANCE MANAGER ===${NC}\n"
    echo -e "\t1. Manage Accounts (Wallet, Bank, ETC & Currency)"
    echo -e "\t2. Manage Categories (Income, Expense)"
    echo -e "\t3. Record Transaction (Income, Expense, Transfer)"
    echo -e "\t4. Budget Targets (Expense Budgeting)"
    echo -e "\t5. Financial Summary & Health Status"
    echo -e "\t6. Monthly Transaction Logs (Sum, Net, & MoM)"
    echo -e "\t7. Transaction Management (Edit & Delete)"
    echo -e "\t8. Debts & Receivables (Debt Tracker)"
    echo -e "\t9. Exchange Rates & Currency Conversion"
    echo -e "\t10. Export & Backup Data"
    echo -e "\t11. Exit"
    echo -e "\t------------------------------------------------"
    echo -ne "\tSelect menu [1-11]: "
    read -r menu_choice

    case $menu_choice in
        1) manage_accounts ;;
        2) manage_categories ;;
        3) add_transaction ;;
        4) manage_budget ;;
        5) show_summary ;;
        6) show_transaction_logs ;;
        7) manage_transactions ;;
        8) manage_debts ;;
        9) manage_exchange ;;
        10) manage_export ;;
        11) echo -e "\n\t${GREEN}Thank you for using Personal Finance Manager!${NC}\n"; exit 0 ;;
        *) echo -e "\n\t${RED}Invalid choice, please try again.${NC}"; sleep 1 ;;
    esac
done
