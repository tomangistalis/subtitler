import Foundation
import XCTest
@testable import Subtitler

class FileHashTests: XCTestCase {
    
    func file(_ name: String) -> String {
        return Bundle(for: FileHashTests.self).resourcePath! + name
    }
    
    override func setUp() {
        super.setUp()
        let file = self.file("f1.txt")
        var txt = ""
        for _ in 1...105536 {
            txt += "a"
        }
        try! txt.write(toFile: file, atomically: true, encoding: String.Encoding.utf8)
    }
    
    override func tearDown() {
        super.tearDown()
        let file = self.file("f1.txt")
        let fileManager = FileManager.default
        try! fileManager.removeItem(atPath: file)
    }
    
    func testHashFile() {
        let file = self.file("f1.txt")
        let hash = fileHash(file)!
        XCTAssertEqual(hash.size, 105536)
        XCTAssertEqual(hash.hash, "585858585859dc40")
    }
    
}
