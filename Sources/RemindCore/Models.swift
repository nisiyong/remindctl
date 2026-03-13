import Foundation

public enum ReminderPriority: String, Codable, CaseIterable, Sendable {
  case none
  case low
  case medium
  case high

  public init(eventKitValue: Int) {
    switch eventKitValue {
    case 1...4:
      self = .high
    case 5:
      self = .medium
    case 6...9:
      self = .low
    default:
      self = .none
    }
  }

  public var eventKitValue: Int {
    switch self {
    case .none:
      return 0
    case .high:
      return 1
    case .medium:
      return 5
    case .low:
      return 9
    }
  }
}

public struct ReminderList: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public struct ReminderItem: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let notes: String?
  public let tags: [String]
  public let isCompleted: Bool
  public let completionDate: Date?
  public let priority: ReminderPriority
  public let dueDate: Date?
  public let listID: String
  public let listName: String

  public init(
    id: String,
    title: String,
    notes: String?,
    tags: [String],
    isCompleted: Bool,
    completionDate: Date?,
    priority: ReminderPriority,
    dueDate: Date?,
    listID: String,
    listName: String
  ) {
    self.id = id
    self.title = title
    self.notes = notes
    self.tags = normalizeTagNames(tags)
    self.isCompleted = isCompleted
    self.completionDate = completionDate
    self.priority = priority
    self.dueDate = dueDate
    self.listID = listID
    self.listName = listName
  }
}

public struct ReminderDraft: Sendable {
  public let title: String
  public let notes: String?
  public let tags: [String]
  public let dueDate: Date?
  public let priority: ReminderPriority

  public init(title: String, notes: String?, tags: [String] = [], dueDate: Date?, priority: ReminderPriority) {
    self.title = title
    self.notes = notes
    self.tags = normalizeTagNames(tags)
    self.dueDate = dueDate
    self.priority = priority
  }
}

public struct ReminderUpdate: Sendable {
  public let title: String?
  public let notes: String?
  public let addTags: [String]?
  public let removeTags: [String]?
  public let dueDate: Date??
  public let priority: ReminderPriority?
  public let listName: String?
  public let isCompleted: Bool?

  public init(
    title: String? = nil,
    notes: String? = nil,
    addTags: [String]? = nil,
    removeTags: [String]? = nil,
    dueDate: Date?? = nil,
    priority: ReminderPriority? = nil,
    listName: String? = nil,
    isCompleted: Bool? = nil
  ) {
    self.title = title
    self.notes = notes
    self.addTags = addTags.map(normalizeTagNames)
    self.removeTags = removeTags.map(normalizeTagNames)
    self.dueDate = dueDate
    self.priority = priority
    self.listName = listName
    self.isCompleted = isCompleted
  }
}

public struct ReminderTagSummary: Codable, Sendable, Equatable {
  public let name: String
  public let reminderCount: Int

  public init(name: String, reminderCount: Int) {
    self.name = name
    self.reminderCount = reminderCount
  }
}

func normalizeTagNames<S: Sequence>(_ tags: S) -> [String] where S.Element == String {
  var seen = Set<String>()
  var normalized: [String] = []
  for raw in tags {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { continue }
    if seen.insert(value).inserted {
      normalized.append(value)
    }
  }
  return normalized
}
