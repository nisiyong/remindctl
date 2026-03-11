import Testing

@testable import RemindCore

@MainActor
struct ReminderTagsTests {
  @Test("normalizeTagNames trims empties and deduplicates")
  func normalizeTags() {
    let tags = normalizeTagNames([" Work ", "", "Q1", "Work", "  ", "Q1", "Ops"])
    #expect(tags == ["Work", "Q1", "Ops"])
  }

  @Test("Reminder item stores normalized tags")
  func reminderItemNormalizesTags() {
    let item = ReminderItem(
      id: "123",
      title: "Finish report",
      notes: nil,
      tags: [" Work ", "Q1", "Work"],
      isCompleted: false,
      completionDate: nil,
      priority: .medium,
      dueDate: nil,
      listID: "list-1",
      listName: "Work"
    )

    #expect(item.tags == ["Work", "Q1"])
  }
}
