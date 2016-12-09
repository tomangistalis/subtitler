import Foundation
import Alamofire
import GZIP

public enum SubtitlerError: Error {
    case unableToWrite, unknownError, notReady, unableToGetHash, unzipError
    case clientError(_: OpenSubtitlesError)
    case downloadError(_: NSError)
}

private func unzip(_ data: Data, to: String) -> Bool {
    if !(data as NSData).isGzippedData() {
        return false
    }

    if let content = (data as NSData).gunzipped() {
        return ((try? content.write(to: URL(fileURLWithPath: to), options: [.atomic])) != nil)
    } else {
        return false
    }
}

public func subtitlesPath(_ path: String) -> String {
    if let idx = path.characters.reversed().index(of: ".") {
        return path[path.startIndex ..< idx.base] + "srt"
    }
    return path + ".srt"
}

open class Subtitler: NSObject {
    var lang: String
    var userAgent: String
    var client: OpenSubtitlesClient
    var loggedIn: Bool = false

    public init(lang: String, userAgent: String) {
        self.lang = lang
        self.userAgent = userAgent
        self.client = OpenSubtitlesClient(userAgent: userAgent, lang: lang)
    }

    fileprivate func login(_ onComplete: @escaping (OpenSubtitlesError?) -> Void) {
        self.client.login { result in
            switch result {
            case .success(_):
                self.loggedIn = true
                onComplete(nil)
            case .failure(let error):
                onComplete(error as? OpenSubtitlesError)
            }
        }
    }

    fileprivate func downloadSubtitlesFile(_ url: String, _ path: String, _ onComplete: @escaping (Result<String>) -> Void) {
        let urlRequest = try! URLRequest(url: url, method: .get)

        Alamofire.request(urlRequest).responseData { dataResponse in
            switch dataResponse.result {
            case .success(let data):
                if unzip(data, to: path) {
                    onComplete(Result.success(path))
                } else {
                    onComplete(Result.failure(SubtitlerError.unzipError))
                }
            case .failure(let error):
                onComplete(Result.failure(SubtitlerError.downloadError(error as NSError)))
            }
        }
    }

    fileprivate func searchSubtitles(_ path: String, _ lang: String, _ onComplete: @escaping (Result<String>) -> Void) {
        if let fh = fileHash(path) {
            self.client.searchSubtitle(fh.hash, fh.size, lang) { result in
                switch result {
                case .success(let url):
                    let finalPath = subtitlesPath(path)
                    self.downloadSubtitlesFile(url, finalPath, onComplete)
                case .failure(let error):
                    onComplete(Result.failure(SubtitlerError.clientError(error as! OpenSubtitlesError)))
                }
            }
        } else {
            onComplete(Result.failure(SubtitlerError.unableToGetHash))
        }
    }

    open func download(_ path: String, onComplete: @escaping (Result<String>) -> Void) {
        download(path, lang: self.lang, onComplete: onComplete)
    }

    open func download(_ path: String, lang: String, onComplete: @escaping (Result<String>) -> Void) {
        if !self.loggedIn {
            self.login { err in
                if let error = err {
                    onComplete(Result.failure(SubtitlerError.clientError(error)))
                } else {
                    self.searchSubtitles(path, lang, onComplete)
                }
            }
        } else {
            self.searchSubtitles(path, lang, onComplete)
        }
    }
}
