import EventKit
import Foundation

public actor RemindersStore {
  private let eventStore = EKEventStore()
  private let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func requestAccess() async throws {
    let status = Self.authorizationStatus()
    switch status {
    case .notDetermined:
      let updated = try await requestAuthorization()
      if updated != .fullAccess {
        throw RemindCoreError.accessDenied
      }
    case .denied, .restricted:
      throw RemindCoreError.accessDenied
    case .writeOnly:
      throw RemindCoreError.writeOnlyAccess
    case .fullAccess:
      break
    }
  }

  public static func authorizationStatus() -> RemindersAuthorizationStatus {
    RemindersAuthorizationStatus(eventKitStatus: EKEventStore.authorizationStatus(for: .reminder))
  }

  public func requestAuthorization() async throws -> RemindersAuthorizationStatus {
    let status = Self.authorizationStatus()
    switch status {
    case .notDetermined:
      let granted = try await requestFullAccess()
      return granted ? .fullAccess : .denied
    default:
      return status
    }
  }

  public func lists() async -> [ReminderList] {
    eventStore.calendars(for: .reminder).map { calendar in
      ReminderList(id: calendar.calendarIdentifier, title: calendar.title)
    }
  }

  public func defaultListName() -> String? {
    eventStore.defaultCalendarForNewReminders()?.title
  }

  public func reminders(in listName: String? = nil) async throws -> [ReminderItem] {
    let calendars: [EKCalendar]
    if let listName {
      calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
      if calendars.isEmpty {
        throw RemindCoreError.listNotFound(listName)
      }
    } else {
      calendars = eventStore.calendars(for: .reminder)
    }

    return await fetchReminders(in: calendars)
  }

  public func tags() async throws -> [ReminderTagSummary] {
    try ensureTagSupport()
    let reminders = try await reminders(in: nil)
    var counts: [String: Int] = [:]
    for reminder in reminders {
      for tag in Set(reminder.tags) {
        counts[tag, default: 0] += 1
      }
    }
    return counts.keys.sorted().map { ReminderTagSummary(name: $0, reminderCount: counts[$0] ?? 0) }
  }

  public func createList(name: String) async throws -> ReminderList {
    let list = EKCalendar(for: .reminder, eventStore: eventStore)
    list.title = name
    guard let source = eventStore.defaultCalendarForNewReminders()?.source else {
      throw RemindCoreError.operationFailed("Unable to determine default reminder source")
    }
    list.source = source
    try eventStore.saveCalendar(list, commit: true)
    return ReminderList(id: list.calendarIdentifier, title: list.title)
  }

  public func renameList(oldName: String, newName: String) async throws {
    let calendar = try calendar(named: oldName)
    guard calendar.allowsContentModifications else {
      throw RemindCoreError.operationFailed("Cannot modify system list")
    }
    calendar.title = newName
    try eventStore.saveCalendar(calendar, commit: true)
  }

  public func deleteList(name: String) async throws {
    let calendar = try calendar(named: name)
    guard calendar.allowsContentModifications else {
      throw RemindCoreError.operationFailed("Cannot delete system list")
    }
    try eventStore.removeCalendar(calendar, commit: true)
  }

  public func createReminder(_ draft: ReminderDraft, listName: String) async throws -> ReminderItem {
    let calendar = try calendar(named: listName)
    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = draft.title
    reminder.notes = draft.notes
    reminder.calendar = calendar
    reminder.priority = draft.priority.eventKitValue
    if let dueDate = draft.dueDate {
      reminder.dueDateComponents = calendarComponents(from: dueDate)
    }
    if !draft.tags.isEmpty {
      try ensureTagSupport()
      applyTagNames(draft.tags, to: reminder)
    }
    try eventStore.save(reminder, commit: true)
    return item(from: reminder)
  }

  public func updateReminder(id: String, update: ReminderUpdate) async throws -> ReminderItem {
    let reminder = try reminder(withID: id)

    if let title = update.title {
      reminder.title = title
    }
    if let notes = update.notes {
      reminder.notes = notes
    }
    if let addTags = update.addTags {
      try ensureTagSupport()
      applyTagNames(normalizeTagNames(readTagNames(from: reminder) + addTags), to: reminder)
    }
    if let removeTags = update.removeTags {
      try ensureTagSupport()
      let updatedTags = readTagNames(from: reminder).filter { !Set(removeTags).contains($0) }
      applyTagNames(updatedTags, to: reminder)
    }
    if let dueDateUpdate = update.dueDate {
      if let dueDate = dueDateUpdate {
        reminder.dueDateComponents = calendarComponents(from: dueDate)
      } else {
        reminder.dueDateComponents = nil
      }
    }
    if let priority = update.priority {
      reminder.priority = priority.eventKitValue
    }
    if let listName = update.listName {
      reminder.calendar = try calendar(named: listName)
    }
    if let isCompleted = update.isCompleted {
      reminder.isCompleted = isCompleted
    }

    try eventStore.save(reminder, commit: true)

    return item(from: reminder)
  }

  public func completeReminders(ids: [String]) async throws -> [ReminderItem] {
    var updated: [ReminderItem] = []
    for id in ids {
      let reminder = try reminder(withID: id)
      reminder.isCompleted = true
      try eventStore.save(reminder, commit: true)
      updated.append(item(from: reminder))
    }
    return updated
  }

  public func deleteReminders(ids: [String]) async throws -> Int {
    var deleted = 0
    for id in ids {
      let reminder = try reminder(withID: id)
      try eventStore.remove(reminder, commit: true)
      deleted += 1
    }
    return deleted
  }

  private func requestFullAccess() async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      eventStore.requestFullAccessToReminders { granted, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: granted)
      }
    }
  }

  private func fetchReminders(in calendars: [EKCalendar]) async -> [ReminderItem] {
    struct ReminderData: Sendable {
      let id: String
      let title: String
      let notes: String?
      let tags: [String]
      let isCompleted: Bool
      let completionDate: Date?
      let priority: Int
      let dueDateComponents: DateComponents?
      let listID: String
      let listName: String
    }

    let reminderData = await withCheckedContinuation { (continuation: CheckedContinuation<[ReminderData], Never>) in
      let predicate = eventStore.predicateForReminders(in: calendars)
      eventStore.fetchReminders(matching: predicate) { reminders in
        let data = (reminders ?? []).map { reminder in
          ReminderData(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            tags: self.readTagNames(from: reminder),
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            priority: Int(reminder.priority),
            dueDateComponents: reminder.dueDateComponents,
            listID: reminder.calendar.calendarIdentifier,
            listName: reminder.calendar.title
          )
        }
        continuation.resume(returning: data)
      }
    }

    return reminderData.map { data in
      ReminderItem(
        id: data.id,
        title: data.title,
        notes: data.notes,
        tags: data.tags,
        isCompleted: data.isCompleted,
        completionDate: data.completionDate,
        priority: ReminderPriority(eventKitValue: data.priority),
        dueDate: date(from: data.dueDateComponents),
        listID: data.listID,
        listName: data.listName
      )
    }
  }

  private func reminder(withID id: String) throws -> EKReminder {
    guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
      throw RemindCoreError.reminderNotFound(id)
    }
    return item
  }

  private func calendar(named name: String) throws -> EKCalendar {
    let calendars = eventStore.calendars(for: .reminder).filter { $0.title == name }
    guard let calendar = calendars.first else {
      throw RemindCoreError.listNotFound(name)
    }
    return calendar
  }

  private func calendarComponents(from date: Date) -> DateComponents {
    calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
  }

  private func date(from components: DateComponents?) -> Date? {
    guard let components else { return nil }
    return calendar.date(from: components)
  }

  private func item(from reminder: EKReminder) -> ReminderItem {
    ReminderItem(
      id: reminder.calendarItemIdentifier,
      title: reminder.title ?? "",
      notes: reminder.notes,
      tags: readTagNames(from: reminder),
      isCompleted: reminder.isCompleted,
      completionDate: reminder.completionDate,
      priority: ReminderPriority(eventKitValue: Int(reminder.priority)),
      dueDate: date(from: reminder.dueDateComponents),
      listID: reminder.calendar.calendarIdentifier,
      listName: reminder.calendar.title
    )
  }

  private func ensureTagSupport() throws {
    let reminder = EKReminder(eventStore: eventStore)
    guard reminder.responds(to: NSSelectorFromString("tags")),
      reminder.responds(to: NSSelectorFromString("setTags:"))
    else {
      throw RemindCoreError.unsupported("Reminder tags are not supported on this macOS/EventKit runtime.")
    }
  }

  private func readTagNames(from reminder: EKReminder) -> [String] {
    guard reminder.responds(to: NSSelectorFromString("tags")) else {
      return []
    }
    return decodeTagNames(from: reminder.value(forKey: "tags"))
  }

  private func applyTagNames(_ tags: [String], to reminder: EKReminder) {
    reminder.setValue(normalizeTagNames(tags), forKey: "tags")
  }

  private func decodeTagNames(from value: Any?) -> [String] {
    guard let value else { return [] }
    if let names = value as? [String] {
      return normalizeTagNames(names)
    }
    if let array = value as? NSArray {
      return normalizeTagNames(array.compactMap(decodeTagName(from:)))
    }
    return []
  }

  private func decodeTagName(from value: Any) -> String? {
    if let name = value as? String {
      return name
    }
    guard let object = value as? NSObject else {
      return nil
    }
    if object.responds(to: NSSelectorFromString("name")) {
      return object.value(forKey: "name") as? String
    }
    if object.responds(to: NSSelectorFromString("title")) {
      return object.value(forKey: "title") as? String
    }
    return nil
  }
}
