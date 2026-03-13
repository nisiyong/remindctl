import Foundation
import RemindCore

enum OutputFormat {
  case standard
  case plain
  case json
  case quiet
}

struct ListSummary: Codable, Sendable, Equatable {
  let id: String
  let title: String
  let reminderCount: Int
  let overdueCount: Int
}

struct AuthorizationSummary: Codable, Sendable, Equatable {
  let status: String
  let authorized: Bool
}

struct PlainReminder: Codable, Sendable, Equatable {
  let id: String
  let listName: String
  let isCompleted: Bool
  let priority: String
  let dueDate: String
  let title: String
  let tags: [String]
}

enum OutputRenderer {
  static func printReminders(_ reminders: [ReminderItem], format: OutputFormat) {
    switch format {
    case .standard:
      printRemindersStandard(reminders)
    case .plain:
      printRemindersPlain(reminders)
    case .json:
      printJSON(reminders)
    case .quiet:
      Swift.print(reminders.count)
    }
  }

  static func printLists(_ summaries: [ListSummary], format: OutputFormat) {
    switch format {
    case .standard:
      printListsStandard(summaries)
    case .plain:
      printListsPlain(summaries)
    case .json:
      printJSON(summaries)
    case .quiet:
      Swift.print(summaries.count)
    }
  }

  static func printReminder(_ reminder: ReminderItem, format: OutputFormat) {
    switch format {
    case .standard:
      let due = reminder.dueDate.map { DateParsing.formatDisplay($0) } ?? "no due date"
      Swift.print("✓ \(reminder.title) [\(reminder.listName)] — \(due)\(standardTagSuffix(for: reminder.tags))")
    case .plain:
      Swift.print(plainLine(for: reminder))
    case .json:
      printJSON(reminder)
    case .quiet:
      break
    }
  }

  static func printDeleteResult(_ count: Int, format: OutputFormat) {
    switch format {
    case .standard:
      Swift.print("Deleted \(count) reminder(s)")
    case .plain:
      Swift.print("\(count)")
    case .json:
      let payload = ["deleted": count]
      printJSON(payload)
    case .quiet:
      break
    }
  }

  static func printAuthorizationStatus(_ status: RemindersAuthorizationStatus, format: OutputFormat) {
    switch format {
    case .standard:
      Swift.print("Reminders access: \(status.displayName)")
    case .plain:
      Swift.print(status.rawValue)
    case .json:
      printJSON(AuthorizationSummary(status: status.rawValue, authorized: status.isAuthorized))
    case .quiet:
      Swift.print(status.isAuthorized ? "1" : "0")
    }
  }

  static func printTags(_ tags: [ReminderTagSummary], format: OutputFormat) {
    switch format {
    case .standard:
      printTagsStandard(tags)
    case .plain:
      printTagsPlain(tags)
    case .json:
      printJSON(tags)
    case .quiet:
      Swift.print(tags.count)
    }
  }

  private static func printRemindersStandard(_ reminders: [ReminderItem]) {
    let sorted = ReminderFiltering.sort(reminders)
    guard !sorted.isEmpty else {
      Swift.print("No reminders found")
      return
    }
    for (index, reminder) in sorted.enumerated() {
      let status = reminder.isCompleted ? "x" : " "
      let due = reminder.dueDate.map { DateParsing.formatDisplay($0) } ?? "no due date"
      let priority = reminder.priority == .none ? "" : " priority=\(reminder.priority.rawValue)"
      Swift.print(
        "[\(index + 1)] [\(status)] \(reminder.title) [\(reminder.listName)] — \(due)\(priority)\(standardTagSuffix(for: reminder.tags))"
      )
    }
  }

  private static func printRemindersPlain(_ reminders: [ReminderItem]) {
    let sorted = ReminderFiltering.sort(reminders)
    for reminder in sorted {
      Swift.print(plainLine(for: reminder))
    }
  }

  private static func plainLine(for reminder: ReminderItem) -> String {
    let due = reminder.dueDate.map { isoFormatter().string(from: $0) } ?? ""
    let plainReminder = PlainReminder(
      id: reminder.id,
      listName: reminder.listName,
      isCompleted: reminder.isCompleted,
      priority: reminder.priority.rawValue,
      dueDate: due,
      title: reminder.title,
      tags: reminder.tags
    )
    return [
      plainReminder.id,
      plainReminder.listName,
      plainReminder.isCompleted ? "1" : "0",
      plainReminder.priority,
      plainReminder.dueDate,
      plainReminder.title,
      plainReminder.tags.joined(separator: ","),
    ].joined(separator: "\t")
  }

  private static func printListsStandard(_ summaries: [ListSummary]) {
    guard !summaries.isEmpty else {
      Swift.print("No reminder lists found")
      return
    }
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      let overdue = summary.overdueCount > 0 ? " (\(summary.overdueCount) overdue)" : ""
      Swift.print("\(summary.title) — \(summary.reminderCount) reminders\(overdue)")
    }
  }

  private static func printListsPlain(_ summaries: [ListSummary]) {
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      Swift.print("\(summary.title)\t\(summary.reminderCount)\t\(summary.overdueCount)")
    }
  }

  private static func printTagsStandard(_ tags: [ReminderTagSummary]) {
    guard !tags.isEmpty else {
      Swift.print("No reminder tags found")
      return
    }
    for tag in tags.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
      let label = tag.reminderCount == 1 ? "reminder" : "reminders"
      Swift.print("\(tag.name) — \(tag.reminderCount) \(label)")
    }
  }

  private static func printTagsPlain(_ tags: [ReminderTagSummary]) {
    for tag in tags.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
      Swift.print("\(tag.name)\t\(tag.reminderCount)")
    }
  }

  private static func standardTagSuffix(for tags: [String]) -> String {
    guard !tags.isEmpty else { return "" }
    return " tags=\(tags.joined(separator: ","))"
  }

  private static func printJSON<T: Encodable>(_ payload: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    do {
      let data = try encoder.encode(payload)
      if let json = String(data: data, encoding: .utf8) {
        Swift.print(json)
      }
    } catch {
      Swift.print("Failed to encode JSON: \(error)")
    }
  }

  private static func isoFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }
}
