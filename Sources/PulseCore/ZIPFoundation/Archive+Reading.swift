//
//  Archive+Reading.swift
//  ZIPFoundation
//
//  Copyright © 2017-2022 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

extension Archive {
    /// Read a ZIP `Entry` from the receiver and write it to `url`.
    ///
    /// - Parameters:
    ///   - entry: The ZIP `Entry` to read.
    ///   - url: The destination file URL.
    ///   - bufferSize: The maximum size of the read buffer and the decompression buffer (if needed).
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    /// - Returns: The checksum of the processed content or 0 if the `skipCRC32` flag was set to `true`.
    /// - Throws: An error if the destination file cannot be written or the entry contains malformed content.
    func extract(_ entry: Entry, to url: URL, bufferSize: UInt32 = defaultReadChunkSize, skipCRC32: Bool = false) throws -> CRC32 {
        guard bufferSize > 0 else {
            throw ArchiveError.invalidBufferSize
        }
        let fileManager = FileManager()
        var checksum = CRC32(0)
        switch entry.type {
        case .file:
            guard !fileManager.itemExists(at: url) else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: url.path])
            }
            try fileManager.createParentDirectoryStructure(for: url)
            let destinationRepresentation = fileManager.fileSystemRepresentation(withPath: url.path)
            guard let destinationFile: UnsafeMutablePointer<FILE> = fopen(destinationRepresentation, "wb+") else {
                throw CocoaError(.fileNoSuchFile)
            }
            defer { fclose(destinationFile) }
            let consumer = { _ = try Data.write(chunk: $0, to: destinationFile) }
            checksum = try self.extract(entry, bufferSize: bufferSize, skipCRC32: skipCRC32, consumer: consumer)
        case .directory:
            let consumer = { (_: Data) in
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            checksum = try self.extract(entry, bufferSize: bufferSize, skipCRC32: skipCRC32, consumer: consumer)
        }
        let attributes = FileManager.attributes(from: entry)
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
        return checksum
    }

    /// Read a ZIP `Entry` from the receiver and forward its contents to a `Consumer` closure.
    ///
    /// - Parameters:
    ///   - entry: The ZIP `Entry` to read.
    ///   - bufferSize: The maximum size of the read buffer and the decompression buffer (if needed).
    ///   - consumer: A closure that consumes contents of `Entry` as `Data` chunks.
    /// - Returns: The checksum of the processed content or 0 if the `skipCRC32` flag was set to `true`..
    /// - Throws: An error if the destination file cannot be written or the entry contains malformed content.
    func extract(_ entry: Entry, bufferSize: UInt32 = defaultReadChunkSize, skipCRC32: Bool = false, consumer: Consumer) throws -> CRC32 {
        guard bufferSize > 0 else {
            throw ArchiveError.invalidBufferSize
        }
        var checksum = CRC32(0)
        let localFileHeader = entry.localFileHeader
        fseek(self.archiveFile, entry.dataOffset, SEEK_SET)
        switch entry.type {
        case .file:
            guard let compressionMethod = CompressionMethod(rawValue: localFileHeader.compressionMethod) else {
                throw ArchiveError.invalidCompressionMethod
            }
            switch compressionMethod {
            case .none: checksum = try self.readUncompressed(entry: entry, bufferSize: bufferSize, skipCRC32: skipCRC32, with: consumer)
            case .deflate: checksum = try self.readCompressed(entry: entry, bufferSize: bufferSize, skipCRC32: skipCRC32, with: consumer)
            }
        case .directory:
            try consumer(Data())
        }
        return checksum
    }

    // MARK: - Helpers

    private func readUncompressed(entry: Entry, bufferSize: UInt32, skipCRC32: Bool, with consumer: Consumer) throws -> CRC32 {
        let size = Int(entry.centralDirectoryStructure.uncompressedSize)
        return try Data.consumePart(of: size, chunkSize: Int(bufferSize), skipCRC32: skipCRC32,
                                    provider: { (_, chunkSize) -> Data in
            return try Data.readChunk(of: Int(chunkSize), from: self.archiveFile)
        }, consumer: { (data) in
            try consumer(data)
        })
    }

    private func readCompressed(entry: Entry, bufferSize: UInt32, skipCRC32: Bool, with consumer: Consumer) throws -> CRC32 {
        let size = Int(entry.centralDirectoryStructure.compressedSize)
        return try Data.decompress(size: size, bufferSize: Int(bufferSize), skipCRC32: skipCRC32,
                                   provider: { (_, chunkSize) -> Data in
            return try Data.readChunk(of: chunkSize, from: self.archiveFile)
        }, consumer: { (data) in
            try consumer(data)
        })
    }
}
