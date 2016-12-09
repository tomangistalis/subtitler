import Foundation
import Alamofire
import AlamofireXMLRPC

private let OpenSubtitlesApi: String = "http://api.opensubtitles.org/xml-rpc"

private enum Method: String {
    case LogIn, SearchSubtitles
}

public enum OpenSubtitlesError: Error {
    case notLoggedIn, empty
    case requestError(_: NSError)
    case statusError(_: String)
}

private struct Status {
    var code: Int
    var msg: String
    var success: Bool {
        get {
            return code == 200
        }
    }
}

class OpenSubtitlesClient: NSObject {
    fileprivate var userAgent: String
    fileprivate var lang: String
    fileprivate var token: String = ""

    init(userAgent: String, lang: String) {
        self.userAgent = userAgent
        self.lang = lang
    }

    func login(_ onComplete: @escaping (Result<String>) -> Void) {
        self.request(.LogIn, ["", "", self.lang, self.userAgent], onComplete: { response in
            switch response.result {
            case .success(let node):
                let status = self.status(node)
                if status.success {
                    self.token = node[0]["token"].string!
                    onComplete(Result.success(self.token))
                } else {
                    onComplete(Result.failure(OpenSubtitlesError.statusError(status.msg)))
                }
            case .failure(let error):
                onComplete(Result.failure(OpenSubtitlesError.requestError(error as NSError)))
            }
        })
    }

    func searchSubtitle(_ hash: String, _ size: UInt64, _ lang: String, onComplete: @escaping (Result<String>) -> Void) {
        if self.token == "" {
            onComplete(Result.failure(OpenSubtitlesError.notLoggedIn))
            return
        }

        let params: [String: Any] = ["moviehash": hash, "moviesize": size]

        self.request(.SearchSubtitles, [self.token, [params]], onComplete: { response in
            switch response.result {
            case .success(let node):
                let status = self.status(node)
                if status.success {
                    let data = node[0]["data"]
                    if let link = self.findSubtitle(data, lang) {
                        onComplete(Result.success(link))
                        return
                    }

                    onComplete(Result.failure(OpenSubtitlesError.empty))
                } else {
                    onComplete(Result.failure(OpenSubtitlesError.statusError(status.msg)))
                }
            case .failure(let error):
                onComplete(Result.failure(OpenSubtitlesError.requestError(error as NSError)))
            }
        })
    }

    func searchTVSubtitle(title: String, season: String, episode: String, _ lang: String, onComplete: @escaping (Result<String>) -> Void) {
        if self.token == "" {
            onComplete(Result.failure(OpenSubtitlesError.notLoggedIn))
            return
        }

        let params: [String: Any] = ["query": title, "season": Int(season)!, "episode": Int(episode)!, "sublanguageid": lang]
        self.request(.SearchSubtitles, [self.token, [params]], onComplete: { response in
            switch response.result {
            case .success(let node):
                let status = self.status(node)
                if status.success {
                    let data = node[0]["data"]
                    if let link = self.findSubtitle(data, lang) {
                        onComplete(Result.success(link))
                        return
                    }

                    onComplete(Result.failure(OpenSubtitlesError.empty))
                } else {
                    onComplete(Result.failure(OpenSubtitlesError.statusError(status.msg)))
                }
            case .failure(let error):
                onComplete(Result.failure(OpenSubtitlesError.requestError(error as NSError)))
            }
        })
    }

    fileprivate func findSubtitle(_ subtitles: XMLRPCNode, _ lang: String) -> String? {
        for i in 0..<subtitles.count {
            let sub = subtitles[i]
            if sub["ISO639"].string! == lang {
                return sub["SubDownloadLink"].string!
            }
        }

        return nil
    }

    fileprivate func status(_ root: XMLRPCNode) -> Status {
        let status = root[0]["status"].string!
        let statusCode = Int(status.components(separatedBy: " ")[0])!
        return Status(code: statusCode, msg: status)
    }

    fileprivate func request(_ method: Method, _ params: [Any], onComplete: @escaping (DataResponse<XMLRPCNode>) -> Void)  {
        AlamofireXMLRPC.request(OpenSubtitlesApi, methodName:method.rawValue, parameters:params).responseXMLRPC(completionHandler: onComplete)
    }
    
}
