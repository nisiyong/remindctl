import Testing

@testable import RemindCore
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
    #expect(throws: RemindCoreError.operationFailed("Tag values must not be empty")) {
      try CommandHelpers.parseTags(["   "])
    }
  }
}
