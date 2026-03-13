import Commander
import Foundation
import RemindCore

enum TagsCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "tags",
      abstract: "List reminder tags",
      discussion: "Shows all unique reminder tags with usage counts.",
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "remindctl tags",
        "remindctl tags --plain",
        "remindctl tags --json",
      ]
    ) { _, runtime in
      let store = RemindersStore()
      try await store.requestAccess()
      let tags = try await store.tags()
      OutputRenderer.printTags(tags, format: runtime.outputFormat)
    }
  }
}
