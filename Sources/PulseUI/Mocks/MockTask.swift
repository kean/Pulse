// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

#if DEBUG || STANDALONE_PULSE_APP

package struct MockTask {
    package var kind: Kind = .data
    package let originalRequest: URLRequest
    package var currentRequest: URLRequest { transactions.last!.request }
    package let response: URLResponse
    package let responseBody: Data
    package let transactions: [Transaction]
    package let delay: TimeInterval
    package var decodingError: Error?
    package var taskDescription: String?

    package enum Kind {
        case data
        case upload(size: Int64)
        case download(size: Int64)
    }

    package struct Transaction {
        package let fetchType: URLSessionTaskMetrics.ResourceFetchType
        package let request: URLRequest
        package let response: URLResponse
        package let duration: TimeInterval
        package var isReusedConnection: Bool = false
    }

    package var duration: TimeInterval {
        transactions.map(\.duration).reduce(0, +)
    }
}

extension MockTask {
    package static let allEntities: [NetworkTaskEntity]  = MockTask.allTasks.map(LoggerStore.preview.entity)

    package static var allTasks: [MockTask] = [.login, .profile, .repos, .octocat, .downloadNuke, .createAPI, .uploadPulseArchive, .patchRepo]

    /// A successful request the demonstrates:
    ///
    /// - Query parameters in URL
    package static let login = MockTask(
        originalRequest: mockLoginOriginalRequest,
        response: mockLoginResponse,
        responseBody: mockLoginResponseBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockLoginCurrentRequest, response: mockLoginResponse, duration: 0.42691)
        ],
        delay: 0.4
    )

    /// A failing request:
    ///
    /// - HTTP status code (404) that doesn't pass validation
    package static let profile = MockTask(
        originalRequest: mockProfileOriginalRequest,
        response: mockProfileFailureResponse,
        responseBody: mockProfileFailureResponseBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockProfileCurrentRequest, response: mockProfileFailureResponse, duration: 0.22691)
        ],
        delay: 2.0
    )

    /// A successful request that demonstrates:
    ///
    /// - Large response body to check FileViewer performance
    package static let repos = MockTask(
        originalRequest: mockReposOriginalRequest,
        response: mockReposResponse,
        responseBody: mockReposBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockReposCurrentRequest, response: mockReposResponse, duration: 0.52691)
        ],
        delay: 2.0
    )

    /// A successful response:
    ///
    /// - Image in the response with a respective "Content-Type"
    /// - Local cache lookup with further validation (302)
    package static let octocat = MockTask(
        originalRequest: mockOctocatOriginalRequest,
        response: mockOctocatResponse,
        responseBody: mockOcotocatResponseBody,
        transactions: [
            .init(fetchType: .localCache, request: mockOctocatCurrentRequest, response: mockOctocatResponse, duration: 0.003),
            .init(fetchType: .networkLoad, request: mockOctocatCurrentRequest, response: mockOctocatNotModifiedResponse, duration: 0.2239)
        ],
        delay: 3.5
    )

    package static let downloadNuke = MockTask(
        kind: .download(size: 6695689),
        originalRequest: mockDownloadNukeOriginalRequest,
        response: mockDownloadNukeResponse,
        responseBody: Data(),
        transactions: [
            .init(fetchType: .networkLoad, request: mockDownloadNukeOriginalRequest, response: mockDownloadNukeRedirectResponse, duration: 0.21283),
            .init(fetchType: .networkLoad, request: mockDownloadNukeCurrentRequest, response: mockDownloadNukeResponse, duration: 4.25254, isReusedConnection: true)
        ],
        delay: 3.5
    )

    package static let uploadPulseArchive = MockTask(
        kind: .upload(size: 21851748),
        originalRequest: mockUploadPulseOriginalRequest,
        response: mockUploadPulseResponse,
        responseBody: Data(),
        transactions: [
            .init(fetchType: .networkLoad, request: mockUploadPulseCurrentRequest, response: mockUploadPulseResponse, duration: 2.21283, isReusedConnection: true)
        ],
        delay: 6.5,
        taskDescription: "upload-pulse-archive"
    )

    package static let createAPI = MockTask(
        originalRequest: mockCreateAPIOriginalRequest,
        response: mockCreateaAPIResponse,
        responseBody: mockCreateaAPIBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockCreateAPICurrentRequest, response: mockCreateaAPIRedirectResponse, duration: 0.20283),
            .init(fetchType: .localCache, request: mockCreateAPIRedirectRequest, response: mockCreateaAPIResponse, duration: 0.003),
            .init(fetchType: .networkLoad, request: mockCreateAPIRedirectRequest, response: mockCreateAPIResponseNotChanged, duration: 0.0980, isReusedConnection: true)
        ],
        delay: 5.5
    )

    /// A failing request:
    ///
    /// - Contains Query Items in the response body
    /// - Fails with a decoding error
    package static let patchRepo = MockTask(
        originalRequest: mockPatchRepoOriginalRequest,
        response: mockPatchRepoResponse,
        responseBody: mockPatchRepoResponseBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockPatchRepoCurrentRequest, response: mockPatchRepoResponse, duration: 1.32691)
        ],
        delay: 6.5,
        decodingError: mockPatchRepoDecodingError
    )

    package static let networkingFailure = MockTask(
        originalRequest: mockLoginOriginalRequest,
        response: mockLoginResponse,
        responseBody: mockLoginResponseBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockLoginCurrentRequest, response: mockLoginResponse, duration: 0.42691)
        ],
        delay: 0.4,
        decodingError: URLError(URLError.Code.notConnectedToInternet)
    )

    // MARK: - Additional Mock Tasks

    package static let searchRepos = _mockTask(
        url: "https://api.github.com/search/repositories?q=swift&sort=stars",
        responseBody: #"{"total_count":245832,"incomplete_results":false,"items":[{"id":44838949,"name":"swift","full_name":"apple/swift","description":"The Swift Programming Language","stargazers_count":67891,"language":"C++"},{"id":79171906,"name":"Alamofire","full_name":"Alamofire/Alamofire","description":"Elegant HTTP Networking in Swift","stargazers_count":41234,"language":"Swift"}]}"#,
        duration: 0.48
    )

    package static let notifications = _mockTask(
        url: "https://api.github.com/notifications",
        responseBody: #"[{"id":"1","reason":"subscribed","subject":{"title":"Fix memory leak in ImagePipeline","url":"https://api.github.com/repos/kean/nuke/issues/432","type":"Issue"},"updated_at":"2024-01-15T10:30:00Z"},{"id":"2","reason":"mention","subject":{"title":"Add Swift 6 support","url":"https://api.github.com/repos/kean/pulse/pulls/89","type":"PullRequest"},"updated_at":"2024-01-15T09:15:00Z"}]"#,
        duration: 0.22
    )

    package static let starRepo = _mockTask(
        url: "https://api.github.com/user/starred/kean/Nuke",
        method: "PUT",
        statusCode: 204,
        responseBody: "",
        duration: 0.15
    )

    package static let pullRequests = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/pulls?state=open",
        responseBody: #"[{"number":456,"title":"Add support for progressive JPEG decoding","state":"open","user":{"login":"contributor1"},"created_at":"2024-01-14T08:00:00Z"},{"number":455,"title":"Fix race condition in prefetcher","state":"open","user":{"login":"contributor2"},"created_at":"2024-01-13T14:30:00Z"},{"number":453,"title":"Update documentation for v12","state":"open","user":{"login":"kean"},"created_at":"2024-01-12T10:00:00Z"}]"#,
        duration: 0.35
    )

    package static let userOrgs = _mockTask(
        url: "https://api.github.com/user/orgs",
        responseBody: #"[{"login":"CreateAPI","id":12345,"description":"Swift OpenAPI tools","url":"https://api.github.com/orgs/CreateAPI"},{"login":"swift-server","id":67890,"description":"Swift on server","url":"https://api.github.com/orgs/swift-server"}]"#,
        duration: 0.19
    )

    package static let gists = _mockTask(
        url: "https://api.github.com/gists",
        responseBody: #"[{"id":"abc123","description":"Swift concurrency examples","files":{"example.swift":{"filename":"example.swift","language":"Swift","size":1024}},"created_at":"2024-01-10T08:00:00Z","public":true},{"id":"def456","description":"URLSession configuration snippets","files":{"config.swift":{"filename":"config.swift","language":"Swift","size":512}},"created_at":"2024-01-08T12:00:00Z","public":false}]"#,
        duration: 0.28
    )

    package static let issues = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/issues?state=open&labels=bug",
        responseBody: #"[{"number":430,"title":"Image flickering on iOS 17.2","state":"open","labels":[{"name":"bug","color":"d73a4a"}],"user":{"login":"user1"}},{"number":428,"title":"Memory spike when loading large GIFs","state":"open","labels":[{"name":"bug","color":"d73a4a"},{"name":"performance","color":"fbca04"}],"user":{"login":"user2"}}]"#,
        duration: 0.31
    )

    package static let userEvents = _mockTask(
        url: "https://api.github.com/users/kean/received_events",
        responseBody: #"[{"type":"PushEvent","repo":{"name":"kean/nuke"},"created_at":"2024-01-15T11:00:00Z","payload":{"commits":[{"message":"Fix image cache eviction"}]}},{"type":"IssuesEvent","repo":{"name":"kean/pulse"},"created_at":"2024-01-15T10:30:00Z","payload":{"action":"opened","issue":{"title":"Console crash on watchOS"}}}]"#,
        duration: 0.26
    )

    package static let followers = _mockTask(
        url: "https://api.github.com/users/kean/followers",
        responseBody: #"[{"login":"alice","id":1001,"avatar_url":"https://avatars.githubusercontent.com/u/1001"},{"login":"bob","id":1002,"avatar_url":"https://avatars.githubusercontent.com/u/1002"},{"login":"charlie","id":1003,"avatar_url":"https://avatars.githubusercontent.com/u/1003"}]"#,
        duration: 0.20
    )

    package static let createIssue = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/issues",
        method: "POST",
        statusCode: 201,
        requestBody: #"{"title":"Crash when cancelling prefetch","body":"Steps to reproduce:\n1. Start prefetching\n2. Cancel immediately\n3. App crashes","labels":["bug"]}"#,
        responseBody: #"{"number":435,"title":"Crash when cancelling prefetch","state":"open","user":{"login":"kean"},"created_at":"2024-01-15T12:00:00Z","html_url":"https://github.com/kean/nuke/issues/435"}"#,
        duration: 0.41
    )

    package static let deleteRepo = _mockTask(
        url: "https://api.github.com/repos/kean/deprecated-project",
        method: "DELETE",
        statusCode: 403,
        responseBody: #"{"message":"Must have admin rights to Repository.","documentation_url":"https://docs.github.com/rest/repos/repos#delete-a-repository"}"#,
        duration: 0.12
    )

    package static let rateLimit = _mockTask(
        url: "https://api.github.com/rate_limit",
        responseBody: #"{"resources":{"core":{"limit":5000,"remaining":4892,"reset":1705312800},"search":{"limit":30,"remaining":28,"reset":1705309260},"graphql":{"limit":5000,"remaining":4999,"reset":1705312800}},"rate":{"limit":5000,"remaining":4892,"reset":1705312800}}"#,
        duration: 0.08
    )

    package static let graphQL = _mockTask(
        url: "https://api.github.com/graphql",
        method: "POST",
        requestBody: #"{"query":"{ viewer { login repositories(first: 5, orderBy: {field: STARGAZERS, direction: DESC}) { nodes { name stargazerCount } } } }"}"#,
        responseBody: #"{"data":{"viewer":{"login":"kean","repositories":{"nodes":[{"name":"Nuke","stargazerCount":8142},{"name":"Pulse","stargazerCount":6280},{"name":"Align","stargazerCount":845},{"name":"Get","stargazerCount":812},{"name":"CreateAPI","stargazerCount":465}]}}}}"#,
        duration: 0.55,
        taskDescription: "GetViewerRepositories"
    )

    package static let releaseLatest = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/releases/latest",
        responseBody: #"{"tag_name":"12.4.0","name":"Nuke 12.4","draft":false,"prerelease":false,"published_at":"2024-01-10T10:00:00Z","body":"Improved progressive JPEG decoding. Fixed memory leak in ImagePipeline. Added Swift 6 support.","assets":[{"name":"Nuke-12.4.0.zip","size":6695689,"download_count":1523}]}"#,
        duration: 0.33
    )

    package static let updateProfile = _mockTask(
        url: "https://api.github.com/user",
        method: "PATCH",
        requestBody: #"{"bio":"Creator of Nuke, Pulse, and other open-source Swift libraries","location":"New York","hireable":false}"#,
        responseBody: #"{"login":"kean","id":1567433,"bio":"Creator of Nuke, Pulse, and other open-source Swift libraries","location":"New York","hireable":false,"public_repos":42,"followers":2891}"#,
        duration: 0.29
    )

    package static let rateLimitExceeded = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/traffic/views",
        statusCode: 429,
        requestHeaders: ["Authorization": "Bearer ghp_xxxxxxxxxxxx"],
        responseBody: #"{"message":"API rate limit exceeded for user ID 1567433.","documentation_url":"https://docs.github.com/rest/overview/rate-limits-for-the-rest-api"}"#,
        duration: 0.05
    )

    package static let repoContributors = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/contributors",
        responseBody: #"[{"login":"kean","contributions":1847},{"login":"jshier","contributions":23},{"login":"MaxDesiatov","contributions":12},{"login":"AvdLee","contributions":8}]"#,
        duration: 0.25
    )

    package static let mergeRequest = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/pulls/452/merge",
        method: "PUT",
        requestBody: #"{"merge_method":"squash","commit_title":"Fix race condition in prefetcher (#452)"}"#,
        responseBody: #"{"sha":"abc123def456","merged":true,"message":"Pull Request successfully merged"}"#,
        duration: 0.38
    )

    package static let serverError = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/dispatches",
        method: "POST",
        statusCode: 500,
        requestBody: #"{"event_type":"build","client_payload":{"ref":"main"}}"#,
        responseBody: #"{"message":"Internal Server Error","documentation_url":"https://docs.github.com/rest"}"#,
        duration: 0.72
    )

    package static let labels = _mockTask(
        url: "https://api.github.com/repos/kean/nuke/labels",
        responseBody: #"[{"name":"bug","color":"d73a4a","description":"Something isn't working"},{"name":"enhancement","color":"a2eeef","description":"New feature or request"},{"name":"performance","color":"fbca04","description":"Performance improvements"},{"name":"documentation","color":"0075ca","description":"Improvements or additions to documentation"}]"#,
        duration: 0.16
    )

    /// A protobuf response — exercises
    /// ``ConsoleDelegate/console(responseBodyViewFor:)`` so integrators can
    /// decode the wire format with their own generated types.
    package static let protoUser = MockTask(
        originalRequest: mockProtoUserOriginalRequest,
        response: mockProtoUserResponse,
        responseBody: mockProtoUserResponseBody,
        transactions: [
            .init(fetchType: .networkLoad, request: mockProtoUserCurrentRequest, response: mockProtoUserResponse, duration: 0.18)
        ],
        delay: 0.2,
        taskDescription: "example.v1.UserService.GetUser"
    )
}

// MARK: - Login (POST)

private let mockLoginOriginalRequest = URLRequest(
    url: "https://github.com/login?scopes=profile,repos",
    method: "POST",
    headers: ["Cache-Control": "no-cache"],
    body: "{\"login\":\"example\",\"password\":\"example2\"}"
)

private let mockLoginCurrentRequest = mockLoginOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
])

private let mockLoginResponse = HTTPURLResponse(url: "https://github.com/login", statusCode: 200, headers: [
    "Set-Cookie": "token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c; path=/; expires=Sun, 30 Jan 2030 21:49:04 GMT; secure; HttpOnly"
])

private let mockLoginResponseBody = """
{
    "access-token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
    "refresh-token": "m1",
    "profile": {
        "id": 1,
        "name": "kean",
        "repos": ["Nuke", "Pulse", "Align"],
        "hireable": false,
        "email": null
    }
}
""".data(using: .utf8)!

// MARK: - Profile (GET, 404)

private let mockProfileOriginalRequest = URLRequest(url: "https://github.com/profile/valdo")

private let mockProfileCurrentRequest = mockProfileOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
])

private let mockProfileFailureResponse = HTTPURLResponse(url: "https://github.com/profile/valdo", statusCode: 404, headers: [
    "Content-Length": "18",
    "Content-Type": "application/html; charset=utf-8",
    "Cache-Control": "no-store",
    "Content-Encoding": "gzip"
])

private let mockProfileFailureResponseBody = """
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Simple 404 Error Page Design</title>
    <link href="https://fonts.googleapis.com/css?family=Roboto:700" rel="stylesheet">
    <style>
    h1 {
        font-size: 80px;
        font-weight: 800;
        text-align: center;
        font-family: 'Roboto', sans-serif;
    }
    h2 {
        font-size: 25px;
        text-align: center;
        font-family: 'Roboto', sans-serif;
        margin-top: -40px;
    }
    p {
        text-align: center;
        font-family: 'Roboto', sans-serif;
        font-size: 12px;
    }
    .container {
        width: 300px;
        margin: 0 auto;
        margin-top: 15%;
    }
    </style>
</head>
<body>
    <div class="container">
    <h1>404</h1>
    <h2>Page Not Found</h2>
    <p>The Page you are looking for doesn't exist or an other error occurred. Go to <a href="">Home Page.</a></p>
    </div>
</body>
</html>
""".data(using: .utf8)!

// MARK: - Octocat (GET, Image)

private let mockOctocatOriginalRequest = URLRequest(url: "https://github.com/octocat.png", headers: [
    "Accept": "image/any"
])

private let mockOctocatCurrentRequest = mockOctocatOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us"
])

private let mockOctocatNotModifiedResponse = HTTPURLResponse(url: "https://github.com/octocat.png", statusCode: 304)

private let mockOctocatResponse = HTTPURLResponse(url: "https://github.com/octocat.png", statusCode: 200, headers: [
    "Content-Length": "11048",
    "Content-Type": "image/png",
    "Cache-Control": "public, max-age=3600",
    "Expires": "Mon, 26 Feb 2021 17:45:57 GMT",
    "Last-Modified": "Mon, 12 Jan 2016 17:45:57 GMT",
    "ETag": "686897696a7c876b7e",
    "Content-Encoding": "gzip"
])

private let mockOcotocatResponseBody = Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAoHBwkHBgoJCAkLCwoMDxkQDw4ODx4WFxIZJCAmJSMgIyIoLTkwKCo2KyIjMkQyNjs9QEBAJjBGS0U+Sjk/QD3/2wBDAQsLCw8NDx0QEB09KSMpPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT3/wgARCAFNAZADAREAAhEBAxEB/8QAHAABAAIDAQEBAAAAAAAAAAAAAAYHAwQFAgEI/8QAGQEBAAMBAQAAAAAAAAAAAAAAAAIDBAEF/9oADAMBAAIQAxAAAAC5QAAAAADjns6oAAAAAAAAByjwdgAAAAAAAAAAAAHg/MBzjslhllG6AAAAAAaRWpXhxjon6fPYAAAAAAAAAAABHD84AA3C3CxzlEdOUc8xH0znTOySIgZUZpgA/R5IwAAAAAAAAAAACBlEgAA2jUPoAAAPh9AABexPAAAAAAAAAAAACvyjQAAAAAAAAAAC8iwAAAAAAAAAAAACIH58AAAAAAAAAAAP0GS8AAAAAAAAAAAA0D8unwAAAAAAAAAA+F8k6AAAAAAAAAAAAKVK3AAAAAAAAAAANo/R52QAAAAAAAAAACLH53PgAAAAAAAAAAAJyXyAAAAAAAAAAAUOQUAAAAAAAAAAAA9H6ZOuAAAAAAAAAAYz8sGAAAAAAAAAAAAAF1ljgAAAAAAAAAHEPzQAADuws7ULNjnfJrd5r95h7HGejJzud3ajLMONCcY9OvQlAACzS5QAAAAAAAAACMH51PgBn522c2yV12ZQAeDwfAez0egAajlZaM8Guz/QCwi8AAAAAAAAAACNn5yPgBb+XZMa7frnQvz5JR51GjHGYAAAySh0b8+OMufRoxu0/pyRK2kCwy7wAAAAAAAAADjH5lPoJNXbdOXZ9Ohfm1rORmrVL7MfPy7AAAB0NWOIV7JPbk2K5c+jTzexoPbg8gswuYAAAAAAAAAAxn5UPALRz6p/TeO5twROrXCqN3fszy2NOCFgAA2J1xmc9PlnKhdbmrx+Fj3iiteLiTrFtFsAAAAAAAAAAA/OJGwW1n1Tam8dnbgpfF7no6s6bCli1argABt2011HdzIW/C6tvhcPF6ApTVijVlYvQnwAAAAABhOQYwezGDIeStCuAWXRpsWjQO3swVLl9jRjZKrccpjVhhYAAM064lK6M1a+hKq2dXkcPHvFD68PHnAX8dQ9GM+GU8gynXMgBzzUOuZAYDkmM+n05xQhgJNXbdWXYN67PjuhG6tMqnm5+XWBpJbDmVwDf1ZItDTJrcvqmzRp0YO8/PG3B5c75ep5Pp5Mp1jMDCcY6RugwnEPh9BnOsZAAVYVAC8cm3vwsG7bRklHQpv88kBGl3TQ6SAHrsd+6jHGWlVeIHdRVejKP0CTEAGE5RgPR5PR3DIDXMx6AAAAPJShXR0IyunLs68ZgADnpbiOknvoegAAcaUKR14tbvLVLdAAAAB4MZnAAAAAAAKyKjMfOz+m+cVX9SMgB5OMszudRAADX7yD20Vvfnd5bxZgAAAAAAAAAABziGnfJIAc8rggRwTpxn24S6UZ7fO5nfQPh4NXvNHseROHBlDr95PSyTpgAAAAAAAAAAA45RLnNlGfFuRnmAByyMkXKoPB6APh8Ngto75JDrgAAAAAAAAAAAAGHsNOymtatNbyjbPYWXC0ADyfnQi56PoAPBgJ6X+AAAAAAAAAAAAAAYZQ15V71d/5+OPOu7+SlUZACDlCgAAAHg/RxJwAAAAAAAAAAAAAADgn5z66kq7C4ksbMxwe8rdyOckNk1iYHNOCZjCC4S0QAAAAAAAAAAAAAAAV0Uoeu8kllOLneNC3W4+Oyw+kSJ4ckjJYJDznFpFwAAAAAAAAAAAAAAAAESKtIqaxumI1yzSPkSJ4ckjJYhzyFlpFwAAAAAAAAAAAAAAAAAHw8nsogghaBHCJE8OSRksM1iClpFwAAAAAAAAAAAAAAAAAAAogghaBHCJE/OMRksM1iClpFwAAAAAAAAAAAAAAAAAAAogghZcoR7nYryU5lDkOx2Mp/KGs7CYytEuEAAAAAAAAAAAAAAAAHk1LKNSyjVsqp2jXEatE+vycSFscrumFufmcnwq7Zpdmwc7EqtE+vy2hdl2a7dqF27Vfk5IAAAAAAAAAAAAAY+85l+Tn3ZfHYgU/l9GL1Xz+/Jw4Wxyu6YW5+ZyfCrtml2bDzsRq0Ta7NaWnAB9d3qtHUz7M8ZgAAAAAAAAAAAa86+Dr87H2AA4ULaYyelj5249fnV/Rrjld0xtz8vk+FXbNLs3dnVV2bdn7y6tnmdeVYA+u9nLv6FWgAAAAAAAAAAARzb5eCVYAjFd9TZt+/OE+uyzOzNSuT0+DXbO78vLjOMVXyq3Pb2rz4DVqhNOrVjK7NnmdLsAB9dkeL1M0ZgAAAAAAAAAARff5HlwADWsaNvPpyceipcfo5uxuvZ5ujyVO5PR+lwbfO3dVA6FPc8AAAkOP09mFoAAAAAAAAAAHLuy8nThAAHNv5ikiePXpJS3Tl71cfPUelOK5tXaspkOnPsQ7v0gABu1aO7l9AAAAAAAAAAAADQtz8nRixSgAOfcwT5tV9wy5jk26++etafM8TncE+bVfd2oAPXJdOjX06NfoAAAAAAAAAAAAHw0bc+lbn1LKfHY8+5gnzar7ilzFJs1989YJ82Id+GCfNqvu7U+u7Vdu7Vo3qtOTnQAAAAAAAAAAAAAABryr0batO2sjqzhhnzLHnjrxJsVyzRl65Pcrnu1W7ELPToAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAH/xABXEAABAwICAgoKDQkGBQUAAAABAgMEBREABgcxEBITITJBUWFxshQgNkBSc5GSscIiIzRDU2JydIGCocHRFTAzN1BUhLPSFhc1QpOiJERFVcNgY2SD4f/aAAgBAQABPwD87PzXQ6VKMafVYcZ8AEtuvBKgDiDmai1MkQarBkK5G30k4v3nOzPRaYbTqtBjq5HH0g4gZrodVlCNAqsOS+QSG2ngpRA77cWG0KWs2SkEk8gxW6s5Wa5OqJJ/4p5Tifk6k/7QnCgFm60pUfjC+KTm2uUMjsCqSUI8Ba90R5qr4oGmhBszX4fTJi3I8zFMq0KsRBKp8pqQwrUttV/z1Sq0KjxDKqMpqOwNa3VADoGK/poQLs0CH0SZVwPMxVs21yuE9n1OStHgIXuaPNTbCQEG6EpSfii2KJVnKNXINRBP/CvJcV8nUr/aVYbWlxCVoN0qAIPKO+tIE80zI9VfBsssFpHSv2OLAbyd4DeHaUqrzqJNEumynYz3GpGpXMoalDpBxlHS5En7SJXwiHJ1B/3lf9GAtKkBQIKSLg8VsVHNdCpJtPq0Jg8heG2xL0v5YY/Quy5PimD62H9OED3ijTV9LrYwdOMniobP15f4IwdN9R4qPD/114Gm6fx0aJ9EleGNOK/f6F5kr8QMMabKR7/TZ7XmLxE0p5Vl66iY3zlpbeIdYp1QZ3SFOjSG/CadSofYcZt0txIG3iUAImSdRf8AeUf14qtXnVuaZdSlOyXuJS9SeZI1JHR2lgd5W+DvHGQJ5qWR6U+TdYYDS+lHse+tMT+0yL8uWyO3NUnGEiIZsrsZG8lnd1hAHIE3tbmwkBF9okJvr2ot+YBI1G2LC5O1FzvE23z2+h1/dsi/IlPDvrTR3Etc01rvjQv3Er55rvfWlGGZeQZ/KxtH/MUCcEWJHewFyAMaLYZiZBgcr+3f89RI76q6IjtHmJnrbRDLC0vFw2SEEb5OCkJO1SvdEjeC7EbYDeBsd8X125+9iLgi5Fxa4xo1zdErtGZptm2J0JoJLI1LQmwC0d9aVc6mfMXQoC7w2D7ev4VweqnvimVOVR6izOgObnJYVtkK9IPKDqIxlmvsZnoTFQjb23FnG+NtY4ST3xpBzL/ZnLDrzJtMfO4x+k6zhRKiSSSTvkk3JPKTy986KszGi5kEF9doc+zfQ7/kPfGlutmpZtMJBuxAQGvrqspXfTa1tLSptZQtJCkqGtKgbg/QQDjK9YFfy3AqPG+ykrHIvUofQe9nnUstLcXwUJKj0DE6Yuoz5E1fDkurePL7Ikj7CB33oVnl/Lc2F+6yvsWAe9s5yTEyXWX2zZaIbpHmnG1CPYjUneHagFSgkAkqNgALknkA48QMm1acASyiM3yvmx6dqN/y2wxo1Wf005Z8Sx+JOP7sm/3ub/pIwdGjf77M+lpOF6OF8VS89j8FDB0eTeKfF+lpQwcg1Xidh+eoerg5ErPJD/1z/TgZCrHLDH/3KPq4Ro+qR4cmI35yvuGEaO5PHUmB0MqPrYb0bpPDnvfUZGBozb/e5v8ApIwdGSOKZN+lpGJWjmY0CWJrR5nWij7bnFRodRpV1TIqkN/CpO2R5Rq+m3baEH7VqqseHGbX5qj3tpJ/V7Wfm+FcI9PaQoT9RlojRW9u6vUNQA4yTxAcuMr5IjUpkPOgLkHW6eF0J8EYajMsj2ttIPLa57UtNq1oSfqjBiMHWy35uOwo/wACjHYUf4FGBGZTqaR5owEJTqSkdA7Qi+vf6cSKbHkJIKAknXYbx6RjOGRDABmUxr2GtbKPtKB6U4BuLjfHaaFe6+X8y9dPe2kJG3yBW/mi8L3lq6dkAk2AJJNgBrJ5BjI2U0UmAH5SAZTwBX9yegbASVEAC5OoYYpotd5R+SMLpjKh7AqScPsLjr2qx0Eaj+ZYYXIXtUDpJ4sIpjKR7MqUeXD1MAF2VG/IcEFJIIsRrGHWkPNlCxcHGfcsfkaf2WwLRnz5iz2mhPuunfMfX72zdFM3J9XjjW5DdA804CtuAvwhfy7OQKP+VsyIKxdqKN1V6E4SkJSEpFgBYDYpscWLyuhOK/mSPQmgCN1kL4DQ9JPEMM6QpYeu/CZLXIgkKxGmRq5TQ/FUFIV5UnkPIcEEEg6x24BJAGs4lzYtBppekKsB5Vq5Bh3SHMLxLUJgNci1EqxQMxx64ydpdqQjhtKxUo4sHkjf1K2K/SW6zR5EVwX26D0g4cbWy6ttwWWhRQoc4Nj6NnQg1euVR3kit9c97PNB5lbZ1LSUn6RbD0dcR9yO5w2VqaPSklP3bOiaKEUqfK41vhHkSNlkBmOkHeCU7+KC7S60ufMniO4+t4iz1jtGhwbX4rYnpjpqMkRDeMHFBs/FvjIk8sVlUT3qSk+enE1ARLXyHf7eCjby0X1DfxmSdHl5vjRJq7QYxSHOS5Fzf/aMZwYpLD0cUsMhZB3UM2KbYo09VMq8aSg2CVgLHKk7xH34fSHWFp5Rs50iiHm+pNjUXQvzkg7Og6L7CsyvjtM976Qqb+S88VNrUh13d0dCxfrX2dFK75YkI8CWv7Qk7M65gP7XXuSreTCAC2i4B3hr2Mr3/tRTvGnqqxUvdf1R29N91fVOMyd0lQ8cfQMWA1DC77RVtdjbEa4itbbXtBfybOkTu3m/Ib6uzobh7hktb/HKlOL82yPzz8piMkqfebaSNZWsJH24OdMuhZbRWIjzngMObqryJucN5xhv2EWFV3+inPI+1aQMHMlR94ytVl9K2EelzBqlfWglmgIB5HpyU9UKwJuazqo9IHTUnPuZwH83HXAoiP4x0/8AjGNvmn4Cjf6zv9OFvZtHAhUVfTKdT6hxpWpdYdMSr1KDCYAHYyzFfW70XuhOzoklAsVSJ8dD3lG12Y5D0ZBO+CmxxWaculVaRFWCAlV0HlQdR+7YyFTS/VFzSPao6Skc6z+AxMWHJSyNQNvJ28Ne5ykE6ibHGeqeqPVxMA9qkpHngWI2KFTlVSsR46QSnbhTh5EA3P4YkrDUdauQbOb5CZWb6q6nUZBT5qQn0p2BcHeBUeIAb5PEMUCJmiiZdg05imUizDIRdc5z0BrAdzXxxKKnokun1Bjb5p+Ao3+s7/Tjd83fuFEP8a6n/wAZwZ2bEf8ARaUvoqa/vax+Vq6hF3MulfMzNbPWCcDMk4EB/LFXb5wWHOq4Tj+2UBtdpMWqseMpz1vOCSMM5yoDzu4isQQ78Gt4IX5qrHDT7byds04haTxpUCO0qlIZqzKGpDsttCFba0eQtkq5iUEEjDGTqCw6HhSYrjw1OvI3VfnKucNMNMJCWm0ISNQSkAbL8yPFTtpD7TQ5VrCfTg50y6HdoiswnV+A06HFeRNzj+2dPXvMR6o/4unP9YpAwvMsnVHy5WXvqNN9dYwK5WHdWWZaPHSmB1VKxmNitZiocqmroUUIfRa654BQrWlQsg74OJsN+BMeiy2y3IYWW3Ecigd/6OMcxGxo+qopebGQs2alpMc9J30k7NNfCCWVHeJunpxXMvRa4yA9dt5HAdTrH4jDOjpYeu/PBa+I1ZWG2I9Gp6Y8RIQkCyBxk8ZPL2k+rxKaUiQshSt8JSkk25cRpTUxhLzCwttWo9o9HjVunKYloC0nhDUQeIg8WHNHTm7e0zxuXx2iVYodAi0NgoYutxdtu6rhKxUZAUQ0g7wN1dOxOltwIL8t5QS2w2pxRPIBfDry5Dy3nf0jqlOK6VEk/adjJNGm1jMjHYUVEnsQiStt10toISd4FQBtdWGqnmL3+gxh4qeFelAwa9WGuHlacvxMlhXpWMIzO/7/AJerLPS0251FnAzrTLgPIqMfx1OfR5SUWw1nHLzzxaFbgB3wFvpQryGxwxIZfTdl1DiTxoUD6Nl6KzITtX2W3E8i0BQ+3C8k0AklqmMxVnW5EuwvzkEHFNp7dMiCO06+6gEkKfeU6vfN+Eok7MmSxDZLsl5tltOtbigkD6Tg5zpjp2lN7Kqa/wD4LCnUefwPKrAqeYpnuWhsxEcs+UL+Y2FdYYFLr8n3bX0MfMIaUfa4V4OToj1jPn1aZ4yc4hJtypQUpwxlGgxnt1ao8EO/CFgKX5xw2w0ykJabQgDUEpA7XSzksyUGvwEXW0i0xHKkal7AJBBSpSSN8KSbEHiI58ZNzIjMdFQ4sjsxkBuQj43hDmOyzUloAS4nbjlvv4XVRb2DZv8AGOHHFOrKlm5PaZhokqZNEmKkOgoCSm4BFunFBp7tOp25vkbopRWQDcJ5u0bdWysKQbHCKqLezbN/inD9RWsbVsbQHj49nShXhGpqKQyv26VZb3M2D6x2ACSALkne3hc40b5VOWsu3kotPmWdf5UeCjtXozEgWeZbcHItAPpw5k6gOvF38kQ0O8bjTQbX5ybHAyg1H/w6rVeGfninh5ru2GBAzJFI7GrMWWjkmQ7LP1mykDzcCsV6Gi8+gbvz0+Ulz/a5tDhGdKOF7SY+uAu9rT2VMfQCoAHDTqHmw40tK0K3wpJuD9OzKhx5iAiUw08hKgsJcQFAKGo7/HhKQlICQABqAH5pSQoEEAg6wcaRNHK6MV1SjNFdO1usI1xvxRsUOty6BUkTYRF+CtCuC4njScZezLAzJE3WG5Z1I9tYXw2zzjt6xPep0Zt9poOIDgDvMnmww83JZS6yoLbULgjFZqgpsb2sJXIcIS22eM8tsNFZaQXAErKQVAcR4+3zLmaHlqBu8ghb67hlgcJw/cOU4qNQk1We9NmObd943UeIcgHIBqA2NGejwlbNcrTPx4rC+ur8240h5BQ4hK0nWFC4OI0ViHHSxGabZZQLJQ2kJSOgD8+QCLHGctEzM8rnUDaR5OtcU7zS8VCmzKVLVFqEV2M+nW24LHpHERzi4xFlPwZKJER5xh5BulxtViP/AM5jvHFD0qOIAarkYr/99j1kYpeZaRWfcE9l08bZO1WOlJ3x2q0JcQpC0hSVCxBFwRg5b3JalQJz8VKjwAbjEGgsRH+yHXHJMjiW6b26O2mT4lPYL0ySzHbGtTqwkfbivaUozILNEa3dfw7tw3+KsT58mpzFypr63318Jazv24gOQcwxBgSqnMREgx3JD6+C22m6iOXmHOd7GStFKKYWp9f2j8sb6I2ttvvitVuDQKcqbUntyYBCb2JJJ1AAb5ODppoAdsItSKPD3IfjfFEz9QK86Goc9AfOpl+7S/oCu0q1FgVuKY1TiNSWuIOC9jyg6wcVzQsg3doM8o5GJVyPPxVskV+i+7KY+W/hWBuqPKnFgpdt5SkcXGk+kYh5mrVO3otUmN8xc248i74j6Tq+zw1xH/lsYZ0uTffaTFX0PkeqcM6XWffqO99R8YGluDx0qZ57eP72qd/2yd5W/wCrH97VO/7ZO8rf9WDpbgcVLm+e3g6W4nFSpf0ut4XpdX71RvPk/gk4f0r1de8xDgsec5iZnvMU3XUi0nkYQlH4nEh9b7odlPKW7xLecKleVRvilZQrta9wUuUseG4jc0ecq2KFoWXvO16d0sRPvWcUWgU2gRNwpkNuOg8IpF1LPKpR3ye+cyUCLmakOQJlwCQpDieEhQ1KGMx5Dq+WruvM7vB4pbFyj6w1oxBqEJikTYcqlsyX399iSbBbJtYYyxnKt5YpkB+vAyqHKA2j4Xt3WMR5DUphDzDiXGnEhSFpNwoHUQe1qWW6PWP8SpkSTzuNAnE7RBlqV+gRKieJfPVVcYr+iel0WA7Odr7kZhHw7CV9XanDstpDq0outAUQlVtrthfeNr73Rjs5vwV47MR4DmOy0/BuY7LT8G5gzUcaF47Ob8FWIL8aTMaakv8AYzKlWW9uZc2g5dqCCfoxSdDUGZFakmvrfZdAWhcZkAEdKttiHofy1G/TiZK8a+R1bYpuVqJRzeBSocc+EhobbFu+5Lm4x1ueCknFKWHYqm1WO1NiDxg40i6NUMsu1ihN/HkREddGGJk2UwxSuzXBEW8gJbUq7aSVABXQL35MZMlycnVZnLVTlIeiTLrgOgEWWOE32y1pbQpayEpSLknUBjPmbHc2VpZCz+TWCRFR6551YDTadSEjFu1U0hfCQk/RhyEk77ZKTycWNFWd3qDVxSai6ewJS7eJcPf0pnslhTd7XxT4RiBZUoEqtgi4xpLykMu14uxkWgTruN/EXrWjFNRUs0ViHCM9wPISQy88sktBPsum9wLYyzmZcl40asrbRWWEA/Fko4nEdrpZrJpmTjGaNnp69w+prXjX2lr6u1caDgscaPK4uv5NhSX17eS2Cw98tH7AzflxrNGXn4C7B3hsOeA4NRwtEukzykhyLLjrsRqU2sa9/FOM/NeZ44k1Mty18CSvWjagkBO12uP7wark2ainZlaFSaKNu1LYsh0p504jaUMsPoQtycuKFi47JYW3h7SVlZrVVm3uZhCnT5Eg4d0uxZktuHQKa/NkPqCGy9ZlH3qxneuVqqVtcauOsXiGyGo/AQVAE2J2ACTYAk6rDFRpsqkzVRJ7JZkJSlSmyQSkKFxe3Hbi2NFtJg1nOBYqUZqUyiI4sNui4uCjGd4Eal50qkOE0GWGnU7RscQLaVEbDER+U1IWwytxMZvdXikX2iL22x5r7Og+TemVeN4EhDnnI/YOkjR8a5eq0pA7PQLOtfDgYKVNOEEKQttViN9KkKB1coIP0jD0l+S4HJD7rywAAp1ZWd7ULk6ubFcz0/XaGID8BhsgpJeQvwTf2KbexvjK2cDlpElHYKJIeIVcrspJAta9jiTPckVR2e2BGdcdLyQySkNk+DhyW/OkvyJTq3nluXUtetRsBv7GjKkIq+dooeF2ooMo9KbBP+440p/rFqPi2epsaGu7lfzB3rt40j/rDrPjUfykbGhdpD2aKkhepcD0rxmGlfkTMM+m/wCSM+pCPkbxT/tI2NB3u+teJY6zn7CzXo9pOaLvrBiz+KS1641KxV9FeY6YslhhE9nw4x9RRBw/TZ0XekQZjPjIzifSMJstW1QdsrwUi58gxGolUmECNTZzpOoIjL9NrYn0idRZRj1KOuO+oB0NrAvtTqO8TyHY0ItA1uqu8kZvrqxpU/WNUfFs9TY0Nd3K/mDvXbxpI/WFWfGo/lI2NCndbP8AmPr40tMBnPslfwrDK+tsaDvd9Z8Sx1nP2IQCLEXGA02DcIT5BsaYu7j+CZ6zmxoQ/wATq3iGeuvGlT9Y1R8Wz1NjQ33cr+YO9dvGkf8AWFWfHI/lI2NCfddP+Y+vjTD3cn5oz6XNjQd7vrPiWOs5+x9Mfdx/BM9ZzY0If4nVvEM9deNKn6xqj4tnqbGhnu0e+YuddGNI/wCsKs+OR/KRsaE+66f8x9fGmHu5PzRn0ubGg73fWfEsdZz9j6Y+7j+CZ6zmxoWfRGn1Yu8bDPWXjSa6H8/z1o8BrqbGiKSIub3l8sNfWRjSC6Hs91dfK6j+UjY0OSURs1Tlr44Xr40tPIfzoVo/dGfX2NB3u+s+JY6zn7DKggXUQByk4dqcdveCiv5Iw5WHDvNtpTzk3w5Pkua3VDmTvY0nErzd/CNevsaKPdtU8Q11l40g92k3ob6uxow7qXfmi+snGd+7OqeNT/LRsaLO6OX819YY0l91p+atelexomuJ1V8S11l4RMkN8F5f0m+G6w+nhpSv7MNVdhW84FIPlGG3m3hdtYUOY9+uuoZRtnFBKeU4kVg76Y6frK/DDrzjxu4tSuk9ppHfQ9m94I96ZbaV0i5I8itjRQCZdU8U11lnGkHu0m9DfV2NGHdS780X1k4zv3Z1Txqf5aNjRZ3Ry/mvrDGk1BGa+mK39hXsaLZiGa5LjL1yWAUdKFdolSkG6SUkcYOGKs63YOjdE8uo4jympKbtq6QdY76ly0RW7nfUeCnlw/IckL2zir8g4h2uZs2Q8uxlAkOzSPao/wB6uROJMh2ZJdkSFlbzqytajxk44r8QxkOhrotABko2kmUd2cHGBayRjSD3aTehvq7GjDuod+aL6ycZ37s6p41P8tGxos7opfzT1saS6IubTGqkwCVwwQ74o7EGa/TprMuKravsLC0E6r8/MRcHmOMvZkhZihh2MsB9I9tYPCQfvHIe1SpSFBSCQoaiMQKhu/tbtg5xHiV3zLfL8hazqvZPR2ufJVVjUNBpIe33LPrZBK0I9IucGDNdUVGLMWtRuSWHCSeUm2/iJlOszCNpBW2PDfIQPx+zGV8hwactEua6JspFiBazaNjPL4fzlUSjUhSW/NSNjRVEK6lPl/5G2ktfWONIkQxs4SF8UltDo6p6uxo3lCNm5CDqkMLa+tvKAxrFjvjGZdHcZ5a5NIeRGcOuMvfb+qRvpxKyxWIdw7AeUBxtDbpPk3/sw1Fnxn0uMx5zTqeCpDLiVDoIGMuuz3qBDcqqCmYW/bARY8xI4iRYkdqlRQoKSbEG4OIzu7x0OeEL98OILbqkKFikkdtIjBads3vKHEOPYSooUFJNiMZnzyzQ2dwYb3WorR9Ru+pSjhxxbzq3HFFbi1FalHWpRNyfKcQIEipzW4kNouvuHeSPSTxDnxluhNZeo7cNshbnDec+EWdZ6OIYznlkZjpoLFhNYuWeRQOtBPIcPsOxX1sPtqbdbNloULFJ58RpLsOU1IjrKHmVhaFDiIxQM5R6/DIQgtTWwN1a9ZJwSVG5Nzy4FyQBrOGIyWwFK31+jt4CC3CbSoWNu+KlBK/bmhdVvZAent5SAh9VtR39iv5Hl1yrLmQpLI24SFId5RvXBGIejjjnz+lDCPsub4ptJhUhjcoLCWgeErWpXSdZxHc3VkE6xvHEt0ttWGtW9iq0KBWUATWApaRZLiTtVp6CMSdGzpXaBPB5n2/vTjLeUF5bfddkyUPPuICbNghKRsQkBT9z/lF+3gQTIWHFj2oHzu+pVNQ+StB2jn2HD8Z2ObOoIHLxHtZvuj6o2IHDX0DEgbWQsc+xAVvrT0HE5V3QnkGxDTeQOYE4m+6PqjYgcNfQO1baW6ratpKjyAYiUkCypBv8QavpwlISLAADvtSQoWIBHPh6lMO76btn4uryYdpL6OBtXB5DhbLjX6RCk9I2Jvuj6o2IHDX0DEr3Sv6NiD+lV8nEz3QegbEH9OfknE39P9UbEDhr6BsJQpZshJUeYXw1TZLmtAQOVRwzSG077qis8g3hhtpDSdqhISOQD9gEAixwuDHc4TSL8oFsScvxpB2wU4g2truPtwvKx/ySvoUj8DhigSGFKO6NKBHOMSKFNW8pSEIUD8cYNDqA/wCXJ6FD8cQ6VNbdUVx1gW5RiVSpq3yUxnCLDfFvxwKLPP8Ayyh0kfjiJRZqHbraSkWtwxh7L8p53bbdoC1tZ/DDeVlHhyvNRiNl9iOSS64snoGG6dGb1NJJ5Vb+EoSgWSAB/wChP//EAC0RAAIBAwEIAgICAgMAAAAAAAECAAMQETESEyAhMkBBUQRQMGEiUhRCYHCQ/9oACAECAQE/AP8Aw3NRRDW/U3x9TfH1N9+pvR6m9Wb1ZvVm9Wb0epvv1N8fU3x9QVh5EDg6fQkgDJj1C3Y06meR+gqPk3Wj7hor4jKVPP8ACqljygorGo+r03zyPfVThb0l8xnCwVj6hw68vwjCLN8fAiOGlVf9hZTg576seYuowAImGyTDjPKUjzxKgw3HTGWEc5fB0lQKMbMU4OYwyMXpnKjva3Vc6Xp9QlXq46XVH6jcaXpdI72sNDdDlQYy7JxaiMnMc5Y8dM4YSquDmyDJxHOFJugwo72oMrek/gx0DCCj7MYhFwPwqQ64MNE+4qBRylVs8hYDJx37rsm61SNYa3oQkk5P4QSDkQVvYjVSdL0lyc9+yhhgxlK69iqljAABgfQEZ1jUfUKldfygE6RaR8wAAYH0hRT4hpLNz+5uT7m5Pubk+5uTNyfc3J9zc/uCiPMFNR4gGO9IxARgjEKkDJ+vUZIErDBzYEn+MdCp+uVtk5lR9vS4y5AjKVOD9iDiDLtzMdCpwbgZOBCMHB+uyTrGqbQxiJU2PEJ55hOf+ylUtpCCDg2RSxxGXZOLKpY4EZSpwfpdYKTGCgPJgpqPErDDWoamVes2o9cqdRtQ6jK3Vah5hRT4hoqdIaLDSEEa96ATyEWj/aBQNOCt1WoamVes2o9cqdRtQ6jK3VaieeOA89Y1EHSMhXXukQuYqhRy4XcLCc87Ul2RKvWbUeqVOs2odRlZcjNgcHMRww5cJAOsqU9nmO5RdkcNQsBymy3qLQdvEWhsczapzY2oDmTKow1qJ/lY0NrpjUXXUTZYeIucc+HWMMHHcA5GeJXI5G2JVfYOBYAk4ERQoxKibYhGDgwHGkpMKl2cnjqHLE9xSqY5HjU5Fq9EltoGL8X+xiU1QYEYYMQZMemr9Ub4uNDKFLZ5mznA46lTZGBr3SVSvIxWDacKaWqRdLPKeln0iaWqacJIGset4XvVqsIKynWAg6WTS1SJ02qaRNLPpE0tUsSBrDVURqxOkJJ1+hDsPMX5DrB8r2I3yVbxF+QgGDP8in7j1kI1i1kA1m/p+4/yEI5GD5KgQ/K9CN8hm8Q1GPn/AIL/AP/EADIRAAIBAgQEBQMEAQUAAAAAAAECAAMRBBAhMRITIFEyM0BBUCIwYRRCUnGBYHCQwfD/2gAIAQMBAT8A/wCDcUmMFDuZyB3nIHecj8zkHvOS05LTktBQb3nIPeCh+ZyB3nJHeGgfYxkZd/gQCTYRKYX0NSlbVfgKacIyJtGrfxgrN7xHDC4+y7hRcw12O0Wub/VN8qqWNx66it2zrt+0SjQNU/iHBLbQyzUXsfsgNWewgwS21MrUGpHXaUH/AGnJhxC0PraGxzY3YysKlPhVNv8AuJfhHFvMYl04u0pG6DrqmyGUEZaJZdzMM1Qg8cqoHQrENmBzqCzH1tDw5r4hDvliPKb/AN7yh4euv4ZQ8tchDvnV8Z9bQOhGbjhYiUnDoGyxlSy8PeUxZR11BdTMJUBTh9xlWcIhaILsBnUN2PraLWbOul/qEo1mpHTaHG6aLBxVXu3QqFtoQQbHoPFSe6wY0W1WVazVTcyglvqORNheE39dTfiGbUQdoKHcxVCiw6KbgCxjtxHToZQwsYaHYxaIGpzrNpw+vVipuIjhtutFDGxhFjYxF4jD1u4Uawkk3PwAJG0Wv/KK6tt1cy+4jOSLDqJA3jVv4wkk3PwgdhsYKzCc89oK47TnjtOeO0547TnjtOeO05/4hrt7Q1WPvCSfWg31EYMWBB0gqKSVG4+PduFSZhWupGRAB4raylVFQXHx1RONSso0jTvfNitNS1ojhxcfIkA6GMRSS4Ep1BUFxmxCi5isGFx8cABtKdAI3EDKtHmW1gUBbQAAWH+5T1FTxRWDC4yqVBTFzEbiUNk7hBcxHDi4+FJtGxCD8xsUfYQ1nPvMMSU1yxWwmH8sZYnwf5lDy1yxXgH9zDeDLFbCCq42MGKYbxcSh30isG2PrWYKLmPivZYzFtz0YYWTLFbCYfyxlifB/mUPLXLFeAf3MN4MsSt1v0AkbRMSw31iVFcaeqqVBTFzHcubnppUi5/EAAFhlXfjbT2mH8sZYnwSh5a5YrwD+5hnseE++TAMLGVaRpmx6QSDcSjW49Dv6mq/GxPThwpb6pdRpeNXpr7ypiS2i6DKgLUxlijoBMO16YHbLEi6ZU8TbRotZG2Mup95UChjw7dIJBuIjcShvUMLGx+zRol9TtBppGYKLmVHLteUavLOu0BuLiEAixlWkaf9faoiyAH1Fejf6l+zRrhF4SI2L/iI9RnN2OaVGTwxcWP3CV63HoB9mhRLm529VUoK+o0MemyeL0oUtoJTw3u8At6xsOjbaRsM421hUruPtDpAJ2i4dzFwqjxawKF0HwJpIdxDhUO0OE7GfpX7w4ap2nIqdpyanacmp2nIqdoMPU7T9K8GEPuYMKo3MFBB7QADb/Qn/9k=")!

// MARK: - Repos (GET, Success)

private let mockReposOriginalRequest = URLRequest(url: "https://github.com/repos")

private let mockReposCurrentRequest = mockReposOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
])

private let mockReposResponse = HTTPURLResponse(url: "https://github.com/repos", statusCode: 200, headers: [
    "Content-Length": "165061",
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Content-Encoding": "gzip"
])

private let mockReposBody = Bundle.main.url(forResource: "repos", withExtension: "json")
    .flatMap { try? Data(contentsOf: $0) } ?? """
    ["Nuke", "Pulse", "Get", "CreateAPI"]
    """.data(using: .utf8)!

// MARK: - /CreateAPI (GET, redirect)

private let mockCreateAPIOriginalRequest = URLRequest(url: "https://github.com/createapi/get")

private let mockCreateAPICurrentRequest = mockCreateAPIOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
])

private let mockCreateAPIRedirectRequest = URLRequest(url: "https://github.com/kean/get").adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
])

private let mockCreateaAPIRedirectResponse = HTTPURLResponse(url: "https://github.com/createapi/get", statusCode: 301, headers: [
    "Content-Type": "text/html; charset=utf-8",
    "Location": "https://github.com/kean/Get",
    "Cache-Control": "no-cache",
    "Content-Length": "0",
    "Server": "GitHub.com"
])

private let mockCreateaAPIResponse = HTTPURLResponse(url: "https://github.com/kean/get", statusCode: 200, headers: [
    "Content-Type": "text/html; charset=utf-8",
    "Content-Length": "90",
    "Cache-Control": "no-store"
])

private let mockCreateAPIResponseNotChanged = HTTPURLResponse(url: "https://github.com/kean/Get", statusCode: 304, headers: [
    "Content-Length": "0",
    "Cache-Control": "max-age=0, private, must-revalidate",
    "Server": "GitHub.com"
])

private let mockCreateaAPIBody = """
<html>
<body>
<title>Get Repo</title>
</body>
</html>
""".data(using: .utf8)!

// MARK: - PATCH

private let mockPatchRepoOriginalRequest: URLRequest = {
    var request = URLRequest(url: "https://github.com/repos/kean/nuke", method: "PATCH")
    request.httpBody = """
    name=ImageKit&description=Image%20Loading%Framework&private=false
    """.data(using: .utf8)
    return request
}()

private let mockPatchRepoCurrentRequest = mockPatchRepoOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Content-Type": "application/x-www-form-urlencoded",
    "Accept": "application/vnd.github+json"
])

private let mockPatchRepoResponse = HTTPURLResponse(url: "https://github.com/repos/kean/nuke", statusCode: 200, headers: [
    "Content-Length": "165061",
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Content-Encoding": "gzip"
])

private let mockPatchRepoResponseBody = """
{
  "id": 1296269,
  "node_id": "MDEwOlJlcG9zaXRvcnkxMjk2MjY5",
  "name": "Hello-World",
  "full_name": "octocat/Hello-World",
  "owner": {
    "login": "octocat",
    "id": 1,
    "node_id": "MDQ6VXNlcjE=",
    "avatar_url": "https://github.com/images/error/octocat_happy.gif",
    "url": "https://api.github.com/users/octocat",
    "html_url": "https://github.com/octocat",
    "type": "User",
    "site_admin": false
  },
  "private": false,
  "description": "This your first repo!",
  "fork": false,
  "url": "https://api.github.com/repos/octocat/Hello-World",
  "homepage": "https://github.com",
  "license": {
    "key": "mit",
    "name": "MIT License",
    "url": "https://api.github.com/licenses/mit"
  },
  "language": null,
  "forks": 9,
  "watchers": 80,
  "size": 108,
  "default_branch": "master",
  "open_issues": 0,
  "is_template": false,
  "topics": [
    "octocat",
    "atom",
    "electron",
    "api"
  ],
  "archived": false,
  "disabled": false,
  "visibility": "public",
  "pushed_at": "2011-01-26T19:06:43Z",
  "created_at": "2011-01-26T19:01:12Z",
  "updated_at": "2011-01-26T19:14:43Z",
  "permissions": {
    "pull": true,
    "push": false,
    "admin": false
  },
  "subscribers_count": 42,
  "organization": {
    "login": "octocat",
    "id": 1,
    "avatar_url": "https://github.com/images/error/octocat_happy.gif",
    "url": "https://api.github.com/users/octocat",
    "type": "Organization",
    "site_admin": false
  }
}
""".data(using: .utf8)!

private let mockPatchRepoDecodingError: Error = {
    struct Repo: Decodable {
        let id: String
    }
    do {
        _ = try JSONDecoder().decode(Repo.self, from: mockPatchRepoResponseBody)
        fatalError()
    } catch {
        return error
    }
}()

// MARK: - Download (GET)

private let mockDownloadNukeOriginalRequest = URLRequest(url: "https://github.com/kean/nuke/archive/tags/11.0.0.zip")

private let mockDownloadNukeCurrentRequest = mockDownloadNukeOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "*/*"
])

private let mockDownloadNukeRedirectResponse = HTTPURLResponse(url: "https://codeload.github.com/kean/nuke/zip/tags/11.0.0", statusCode: 302, headers: [
    "Server": "GitHub.com",
    "Content-Type": "text/html; charset=utf-8",
    "Location": "https://codeload.github.com/kean/Nuke/zip/tags/11.0.0",
    "Cache-Control": "max-age=0, private",
    "Content-Length": "0",
    "Content-Security-Policy": "default-src 'none'; base-uri 'self'; block-all-mixed-content; child-src github.com/assets-cdn/worker/ gist.github.com/assets-cdn/worker/; connect-src 'self' uploads.github.com objects-origin.githubusercontent.com www.githubstatus.com collector.github.com raw.githubusercontent.com api.github.com github-cloud.s3.amazonaws.com github-production-repository-file-5c1aeb.s3.amazonaws.com github-production-upload-manifest-file-7fdce7.s3.amazonaws.com github-production-user-asset-6210df.s3.amazonaws.com cdn.optimizely.com logx.optimizely.com/v1/events *.actions.githubusercontent.com wss://*.actions.githubusercontent.com online.visualstudio.com/api/v1/locations github-production-repository-image-32fea6.s3.amazonaws.com github-production-release-asset-2e65be.s3.amazonaws.com"
])

private let mockDownloadNukeResponse = HTTPURLResponse(url: "https://codeload.github.com/kean/nuke/zip/tags/11.0.0", statusCode: 200, headers: [
    "Content-Type": "application/zip",
    "Content-Disposition": "attachment; filename=Nuke-11.0.0.zip",
    "Etag": "W/\\\"4358c3c3d9bd5a22f6d86b47cbe567417fa1efc8df6beaa54c1730caf6ad86da\\\"",
    "Access-Control-Allow-Origin": "https://render.githubusercontent.com"
])

// MARK: - Upload (POST)

private let mockUploadPulseOriginalRequest = URLRequest(url: "https://objects-origin.githubusercontent.com/github-production-release-asset-2e65be/upload-we9zs7v.zip", method: "POST", headers: [
    "Content-Length": "21851748",
    "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundaryrv8XAHQPtQcWta3k"
])

private let mockUploadPulseCurrentRequest = mockUploadPulseOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0",
    "Accept-Encoding": "gzip",
    "Accept-Language": "en-us",
    "Accept": "*/*"
])

private let mockUploadPulseResponse = HTTPURLResponse(url: "https://objects-origin.githubusercontent.com/github-production-release-asset-2e65be/upload-we9zs7v.zip", statusCode: 204, headers: [
    "Vary": "Origin",
    "Access-Control-Allow-Origin": "https://github.com"
])

// MARK: - PDF

package let mockPDF = Data(base64Encoded: "JVBERi0xLjMNCiXi48/TDQoNCjEgMCBvYmoNCjw8DQovVHlwZSAvQ2F0YWxvZw0KL091dGxpbmVzIDIgMCBSDQovUGFnZXMgMyAwIFINCj4+DQplbmRvYmoNCg0KMiAwIG9iag0KPDwNCi9UeXBlIC9PdXRsaW5lcw0KL0NvdW50IDANCj4+DQplbmRvYmoNCg0KMyAwIG9iag0KPDwNCi9UeXBlIC9QYWdlcw0KL0NvdW50IDINCi9LaWRzIFsgNCAwIFIgNiAwIFIgXSANCj4+DQplbmRvYmoNCg0KNCAwIG9iag0KPDwNCi9UeXBlIC9QYWdlDQovUGFyZW50IDMgMCBSDQovUmVzb3VyY2VzIDw8DQovRm9udCA8PA0KL0YxIDkgMCBSIA0KPj4NCi9Qcm9jU2V0IDggMCBSDQo+Pg0KL01lZGlhQm94IFswIDAgNjEyLjAwMDAgNzkyLjAwMDBdDQovQ29udGVudHMgNSAwIFINCj4+DQplbmRvYmoNCg0KNSAwIG9iag0KPDwgL0xlbmd0aCAxMDc0ID4+DQpzdHJlYW0NCjIgSg0KQlQNCjAgMCAwIHJnDQovRjEgMDAyNyBUZg0KNTcuMzc1MCA3MjIuMjgwMCBUZA0KKCBBIFNpbXBsZSBQREYgRmlsZSApIFRqDQpFVA0KQlQNCi9GMSAwMDEwIFRmDQo2OS4yNTAwIDY4OC42MDgwIFRkDQooIFRoaXMgaXMgYSBzbWFsbCBkZW1vbnN0cmF0aW9uIC5wZGYgZmlsZSAtICkgVGoNCkVUDQpCVA0KL0YxIDAwMTAgVGYNCjY5LjI1MDAgNjY0LjcwNDAgVGQNCigganVzdCBmb3IgdXNlIGluIHRoZSBWaXJ0dWFsIE1lY2hhbmljcyB0dXRvcmlhbHMuIE1vcmUgdGV4dC4gQW5kIG1vcmUgKSBUag0KRVQNCkJUDQovRjEgMDAxMCBUZg0KNjkuMjUwMCA2NTIuNzUyMCBUZA0KKCB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiApIFRqDQpFVA0KQlQNCi9GMSAwMDEwIFRmDQo2OS4yNTAwIDYyOC44NDgwIFRkDQooIEFuZCBtb3JlIHRleHQuIEFuZCBtb3JlIHRleHQuIEFuZCBtb3JlIHRleHQuIEFuZCBtb3JlIHRleHQuIEFuZCBtb3JlICkgVGoNCkVUDQpCVA0KL0YxIDAwMTAgVGYNCjY5LjI1MDAgNjE2Ljg5NjAgVGQNCiggdGV4dC4gQW5kIG1vcmUgdGV4dC4gQm9yaW5nLCB6enp6ei4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kICkgVGoNCkVUDQpCVA0KL0YxIDAwMTAgVGYNCjY5LjI1MDAgNjA0Ljk0NDAgVGQNCiggbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiApIFRqDQpFVA0KQlQNCi9GMSAwMDEwIFRmDQo2OS4yNTAwIDU5Mi45OTIwIFRkDQooIEFuZCBtb3JlIHRleHQuIEFuZCBtb3JlIHRleHQuICkgVGoNCkVUDQpCVA0KL0YxIDAwMTAgVGYNCjY5LjI1MDAgNTY5LjA4ODAgVGQNCiggQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgKSBUag0KRVQNCkJUDQovRjEgMDAxMCBUZg0KNjkuMjUwMCA1NTcuMTM2MCBUZA0KKCB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBFdmVuIG1vcmUuIENvbnRpbnVlZCBvbiBwYWdlIDIgLi4uKSBUag0KRVQNCmVuZHN0cmVhbQ0KZW5kb2JqDQoNCjYgMCBvYmoNCjw8DQovVHlwZSAvUGFnZQ0KL1BhcmVudCAzIDAgUg0KL1Jlc291cmNlcyA8PA0KL0ZvbnQgPDwNCi9GMSA5IDAgUiANCj4+DQovUHJvY1NldCA4IDAgUg0KPj4NCi9NZWRpYUJveCBbMCAwIDYxMi4wMDAwIDc5Mi4wMDAwXQ0KL0NvbnRlbnRzIDcgMCBSDQo+Pg0KZW5kb2JqDQoNCjcgMCBvYmoNCjw8IC9MZW5ndGggNjc2ID4+DQpzdHJlYW0NCjIgSg0KQlQNCjAgMCAwIHJnDQovRjEgMDAyNyBUZg0KNTcuMzc1MCA3MjIuMjgwMCBUZA0KKCBTaW1wbGUgUERGIEZpbGUgMiApIFRqDQpFVA0KQlQNCi9GMSAwMDEwIFRmDQo2OS4yNTAwIDY4OC42MDgwIFRkDQooIC4uLmNvbnRpbnVlZCBmcm9tIHBhZ2UgMS4gWWV0IG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gKSBUag0KRVQNCkJUDQovRjEgMDAxMCBUZg0KNjkuMjUwMCA2NzYuNjU2MCBUZA0KKCBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSB0ZXh0LiBBbmQgbW9yZSApIFRqDQpFVA0KQlQNCi9GMSAwMDEwIFRmDQo2OS4yNTAwIDY2NC43MDQwIFRkDQooIHRleHQuIE9oLCBob3cgYm9yaW5nIHR5cGluZyB0aGlzIHN0dWZmLiBCdXQgbm90IGFzIGJvcmluZyBhcyB3YXRjaGluZyApIFRqDQpFVA0KQlQNCi9GMSAwMDEwIFRmDQo2OS4yNTAwIDY1Mi43NTIwIFRkDQooIHBhaW50IGRyeS4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gQW5kIG1vcmUgdGV4dC4gKSBUag0KRVQNCkJUDQovRjEgMDAxMCBUZg0KNjkuMjUwMCA2NDAuODAwMCBUZA0KKCBCb3JpbmcuICBNb3JlLCBhIGxpdHRsZSBtb3JlIHRleHQuIFRoZSBlbmQsIGFuZCBqdXN0IGFzIHdlbGwuICkgVGoNCkVUDQplbmRzdHJlYW0NCmVuZG9iag0KDQo4IDAgb2JqDQpbL1BERiAvVGV4dF0NCmVuZG9iag0KDQo5IDAgb2JqDQo8PA0KL1R5cGUgL0ZvbnQNCi9TdWJ0eXBlIC9UeXBlMQ0KL05hbWUgL0YxDQovQmFzZUZvbnQgL0hlbHZldGljYQ0KL0VuY29kaW5nIC9XaW5BbnNpRW5jb2RpbmcNCj4+DQplbmRvYmoNCg0KMTAgMCBvYmoNCjw8DQovQ3JlYXRvciAoUmF2ZSBcKGh0dHA6Ly93d3cubmV2cm9uYS5jb20vcmF2ZVwpKQ0KL1Byb2R1Y2VyIChOZXZyb25hIERlc2lnbnMpDQovQ3JlYXRpb25EYXRlIChEOjIwMDYwMzAxMDcyODI2KQ0KPj4NCmVuZG9iag0KDQp4cmVmDQowIDExDQowMDAwMDAwMDAwIDY1NTM1IGYNCjAwMDAwMDAwMTkgMDAwMDAgbg0KMDAwMDAwMDA5MyAwMDAwMCBuDQowMDAwMDAwMTQ3IDAwMDAwIG4NCjAwMDAwMDAyMjIgMDAwMDAgbg0KMDAwMDAwMDM5MCAwMDAwMCBuDQowMDAwMDAxNTIyIDAwMDAwIG4NCjAwMDAwMDE2OTAgMDAwMDAgbg0KMDAwMDAwMjQyMyAwMDAwMCBuDQowMDAwMDAyNDU2IDAwMDAwIG4NCjAwMDAwMDI1NzQgMDAwMDAgbg0KDQp0cmFpbGVyDQo8PA0KL1NpemUgMTENCi9Sb290IDEgMCBSDQovSW5mbyAxMCAwIFINCj4+DQoNCnN0YXJ0eHJlZg0KMjcxNA0KJSVFT0YNCg==")!

// MARK: - Mock Task Factory

private func _mockTask(
    url: String,
    method: String = "GET",
    statusCode: Int = 200,
    requestHeaders: [String: String] = [:],
    requestBody: String? = nil,
    responseBody: String = "{}",
    duration: TimeInterval = 0.3,
    delay: TimeInterval = 1.0,
    decodingError: Error? = nil,
    taskDescription: String? = nil
) -> MockTask {
    let originalRequest = URLRequest(url: url, method: method, headers: requestHeaders, body: requestBody)
    let currentRequest = originalRequest.adding(headers: [
        "User-Agent": "Pulse Demo/2.0",
        "Accept-Encoding": "gzip",
        "Accept-Language": "en-us",
        "Accept": "application/json"
    ])
    let response = HTTPURLResponse(url: url, statusCode: statusCode, headers: [
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "private, max-age=60"
    ])
    return MockTask(
        originalRequest: originalRequest,
        response: response,
        responseBody: responseBody.data(using: .utf8) ?? Data(),
        transactions: [
            .init(fetchType: .networkLoad, request: currentRequest, response: response, duration: duration)
        ],
        delay: delay,
        decodingError: decodingError,
        taskDescription: taskDescription
    )
}

// MARK: - Proto User (GET, application/x-protobuf)

private let mockProtoUserOriginalRequest = URLRequest(
    url: "https://api.example.com/example.v1.UserService/GetUser",
    method: "POST",
    headers: [
        "Content-Type": "application/x-protobuf",
        "Accept": "application/x-protobuf",
        "X-Grpc-Message-Type": "example.v1.GetUserRequest"
    ]
)

private let mockProtoUserCurrentRequest = mockProtoUserOriginalRequest.adding(headers: [
    "User-Agent": "Pulse Demo/2.0"
])

private let mockProtoUserResponse = HTTPURLResponse(
    url: "https://api.example.com/example.v1.UserService/GetUser",
    statusCode: 200,
    headers: [
        "Content-Type": "application/x-protobuf",
        "X-Grpc-Message-Type": "example.v1.GetUserResponse"
    ]
)

private let mockProtoUserResponseBody = Data([
    // id = 1567433
    0x08, 0xc9, 0xf5, 0x5f,
    // username = "kean"
    0x12, 0x04, 0x6b, 0x65, 0x61, 0x6e,
    // email = "alex@example.com"
    0x1a, 0x10, 0x61, 0x6c, 0x65, 0x78, 0x40, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0x2e, 0x63, 0x6f, 0x6d,
    // roles = ["owner", "maintainer"]
    0x22, 0x05, 0x6f, 0x77, 0x6e, 0x65, 0x72,
    0x22, 0x0a, 0x6d, 0x61, 0x69, 0x6e, 0x74, 0x61, 0x69, 0x6e, 0x65, 0x72,
    // profile { display_name = "Alex Kean", followers = 354, verified = true }
    0x2a, 0x10,
    0x0a, 0x09, 0x41, 0x6c, 0x65, 0x78, 0x20, 0x4b, 0x65, 0x61, 0x6e,
    0x10, 0xe2, 0x02,
    0x18, 0x01
])

// MARK: Helpers

private extension URLRequest {
    init(url: String, method: String = "GET", headers: [String: String] = [:],
         body: String? = nil) {
        self.init(url: URL(string: url)!)
        self.httpMethod = method
        self.allHTTPHeaderFields = headers
        self.httpBody = body?.data(using: .utf8)
    }

    func adding(headers: [String: String]) -> Self {
        var request = self
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}

private extension HTTPURLResponse {
    convenience init(url: String, statusCode: Int, headers: [String: String] = [:]) {
        self.init(url: URL(string: url)!, statusCode: statusCode, httpVersion: "http/2.0", headerFields: headers)!
    }
}

#endif
