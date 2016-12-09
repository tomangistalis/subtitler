import Foundation

private let chunkSize: Int = 65536

public struct FileHash {
    var hash: String
    var size: UInt64
}

private func applyChunk(_ hash: UInt64, chunk: Data) -> UInt64 {
    let bytes = UnsafeBufferPointer<UInt64>(
        start: (chunk as NSData).bytes.bindMemory(to: UInt64.self, capacity: chunk.count),
        count: chunk.count / MemoryLayout<UInt64>.size
    )

    return bytes.reduce(hash, &+)
}

private func getChunk(_ f: FileHandle, start: UInt64) -> Data {
    f.seek(toFileOffset: start)
    return f.readData(ofLength: chunkSize)
}

private func hexHash(_ hash: UInt64) -> String {
    return String(format:"%qx", hash)
}

private func fileSize(_ f: FileHandle) -> UInt64 {
    f.seekToEndOfFile()
    return f.offsetInFile
}

public func fileHash(_ path: String) -> FileHash? {
    if let f = FileHandle(forReadingAtPath: path) {
        let size = fileSize(f)
        if size < UInt64(chunkSize) {
            return nil
        }

        let start = getChunk(f, start: 0)
        let end = getChunk(f, start: size - UInt64(chunkSize))
        var hash = size
        hash = applyChunk(hash, chunk: start)
        hash = applyChunk(hash, chunk: end)
        
        f.closeFile()
        return FileHash(hash: hexHash(hash), size: size)
    }
    return nil
}

