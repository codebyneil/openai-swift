import Foundation

enum FixtureLoader {
    static func fixtureURL(_ name: String) -> URL {
        // Package root during test execution is the working directory
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fixturesDir = packageRoot.appendingPathComponent("Tests/OpenAIOfflineTests/Fixtures")
        return fixturesDir.appendingPathComponent("\(name).json")
    }

    static func loadData(_ name: String) throws -> Data {
        let url = fixtureURL(name)
        return try Data(contentsOf: url)
    }
}
