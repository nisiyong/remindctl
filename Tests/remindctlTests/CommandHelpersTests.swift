import Testing

@testable import remindctl

@MainActor
struct CommandHelpersTests {
  @Test("parseTags trims and deduplicates values")
  func parseTags() throws {
    let tags = try CommandHelpers.parseTags([" Work ", "Q1", "Work"])
    #expect(tags == ["Work", "Q1"])
  }

  @Test("parseTags rejects empty values")
  func parseTagsRejectsEmpty() {
    #expect(throws: Error.self) {
      try CommandHelpers.parseTags(["   "])
    }
  }
}
