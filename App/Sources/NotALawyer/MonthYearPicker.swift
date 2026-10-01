import SwiftUI

/// Month and year by tapping: a year first, then (optionally) a month. Recent years first,
/// with "Earlier" opening older decades.
struct MonthYearPicker: View {
    @Binding var date: Date?
    var compact = false
    @State private var showEarlier = false

    private let calendar = Calendar(identifier: .gregorian)
    private var currentYear: Int { calendar.component(.year, from: Date()) }
    private var selectedYear: Int? { date.map { calendar.component(.year, from: $0) } }
    private var selectedMonth: Int? { date.map { calendar.component(.month, from: $0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            Text("Year").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: compact ? 6 : 5), spacing: 8) {
                ForEach(years, id: \.self) { year in
                    chip(String(year), selected: selectedYear == year) { setYear(year) }
                }
                if !showEarlier {
                    chip("Earlier", selected: false) { withAnimation(.smooth) { showEarlier = true } }
                }
            }

            if selectedYear != nil {
                Text("Month (optional)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(1...12, id: \.self) { month in
                        chip(calendar.shortMonthSymbols[month - 1], selected: selectedMonth == month && date != nil) { setMonth(month) }
                    }
                }
            }

            if let date {
                Text(howLongAgo(date)).foregroundStyle(.secondary)
            }
        }
        .onAppear { if let y = selectedYear, y < currentYear - 8 { showEarlier = true } }
    }

    private var years: [Int] {
        let recent = Array(stride(from: currentYear, through: currentYear - 8, by: -1))
        return showEarlier ? recent + Array(stride(from: currentYear - 9, through: currentYear - 60, by: -1)) : recent
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(selected ? .semibold : .regular))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 5 : 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.stamp : Color.secondary.opacity(0.1)))
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func setYear(_ year: Int) {
        // Without a month yet, the middle of the year keeps the "years ago" estimate honest.
        let month = selectedMonth ?? 6
        date = calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    private func setMonth(_ month: Int) {
        guard let year = selectedYear else { return }
        date = calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    private func howLongAgo(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date, to: Date())
        let years = c.year ?? 0, months = c.month ?? 0
        let parts = [years > 0 ? "\(years) year\(years == 1 ? "" : "s")" : nil,
                     months > 0 ? "\(months) month\(months == 1 ? "" : "s")" : nil].compactMap { $0 }
        return parts.isEmpty ? "This month" : "About \(parts.joined(separator: " and ")) ago"
    }
}
