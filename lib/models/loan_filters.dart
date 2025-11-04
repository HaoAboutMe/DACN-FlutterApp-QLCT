/// Loan Filter Models
/// Models để quản lý bộ lọc khoản vay và thời gian

class LoanFilters {
  // Status filters (Trạng thái)
  bool filterActive;
  bool filterCompleted;

  // Due date filters (Tình trạng hạn)
  bool filterDueSoon; // Sắp đến hạn (≤7 ngày)
  bool filterOverdue; // Đã quá hạn
  bool filterNoDueDate; // Không có hạn

  // Time filter (Thời gian tạo)
  bool filterAllTime;
  DateTime? selectedMonth; // Null nếu chọn "Tất cả thời gian"

  LoanFilters({
    this.filterActive = false,
    this.filterCompleted = false,
    this.filterDueSoon = false,
    this.filterOverdue = false,
    this.filterNoDueDate = false,
    this.filterAllTime = true,
    this.selectedMonth,
  });

  /// Check if any loan status/due filter is active
  bool get hasLoanFilters =>
      filterActive ||
      filterCompleted ||
      filterDueSoon ||
      filterOverdue ||
      filterNoDueDate;

  /// Check if time filter is active
  bool get hasTimeFilter => !filterAllTime && selectedMonth != null;

  /// Check if any filter is active
  bool get hasAnyFilter => hasLoanFilters || hasTimeFilter;

  /// Reset all filters
  void resetAll() {
    filterActive = false;
    filterCompleted = false;
    filterDueSoon = false;
    filterOverdue = false;
    filterNoDueDate = false;
    filterAllTime = true;
    selectedMonth = null;
  }

  /// Reset loan filters only
  void resetLoanFilters() {
    filterActive = false;
    filterCompleted = false;
    filterDueSoon = false;
    filterOverdue = false;
    filterNoDueDate = false;
  }

  /// Reset time filter only
  void resetTimeFilter() {
    filterAllTime = true;
    selectedMonth = null;
  }

  /// Create a copy with new values
  LoanFilters copyWith({
    bool? filterActive,
    bool? filterCompleted,
    bool? filterDueSoon,
    bool? filterOverdue,
    bool? filterNoDueDate,
    bool? filterAllTime,
    DateTime? selectedMonth,
  }) {
    return LoanFilters(
      filterActive: filterActive ?? this.filterActive,
      filterCompleted: filterCompleted ?? this.filterCompleted,
      filterDueSoon: filterDueSoon ?? this.filterDueSoon,
      filterOverdue: filterOverdue ?? this.filterOverdue,
      filterNoDueDate: filterNoDueDate ?? this.filterNoDueDate,
      filterAllTime: filterAllTime ?? this.filterAllTime,
      selectedMonth: selectedMonth ?? this.selectedMonth,
    );
  }
}

