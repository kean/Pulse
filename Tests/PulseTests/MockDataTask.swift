// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

struct MockDataTask {
    let request: URLRequest
    let response: URLResponse
    let responseBody: Data
    let metrics: NetworkLogger.Metrics
}

// MARK: - GitHub Login (Success)

extension MockDataTask {
    static let login = MockDataTask(
        request: mockLoginRequest,
        response: mockLoginResponse,
        responseBody: MockJSON.githubLoginResponse,
        metrics: mockMetrics
    )
}

private let mockLoginRequest: URLRequest = {
    var request = URLRequest(url: URL(string: "https://github.com/login")!)
    request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("github.com", forHTTPHeaderField: "Host")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.setValue("en-us", forHTTPHeaderField: "Accept-Language")
    request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
    return request
}()

private let mockLoginResponse = HTTPURLResponse(url: URL(string: "https://github.com/login")!, statusCode: 200, httpVersion: "2.0", headerFields: [
    "Set-Cookie": "token=ADSJ1239CX0; path=/; expires=Sun, 30 Jan 2030 21:49:04 GMT; secure; HttpOnly"
])!

private let mockMetrics = try! JSONDecoder().decode(NetworkLogger.Metrics.self, from: """
{
  "transactions": [
    {
      "transferSize": [167, 0, 0, 94, 166, 214],
      "timing": [681270022.377544, 681270022.3860258, 681270022.4066201, 681270022.4071407, 681270022.4251491, 681270022.533362, 681270022.5338686, 681270022.5343999, 681270022.5381376, 681270022.7511908, 681270022.8044541],
      "networkProtocol": "http/2.0",
      "conditions": 0,
      "request": {
        "url": "https://github.com/login?scopes=profile,repos",
        "method": "POST",
        "headers": {
          "User-Agent": "Pulse Demo/2.0",
          "Accept-Encoding": "gzip",
          "Cache-Control": "no-cache",
          "Accept-Language": "en-us",
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        },
        "options": 15,
        "timeout": 60
      },
      "response": {
        "statusCode": 200,
        "headers": {
          "Set-Cookie": "token=ADSJ1239CX0; path=/; expires=Sun, 30 Jan 2030 21:49:04 GMT; secure; HttpOnly"
        }
      },
      "localAddress": "192.168.0.13",
      "remotePort": 443,
      "remoteAddress": "17.253.97.204",
      "localPort": 58622,
      "tlsVersion": 772,
      "tlsSuite": 4865
    }
  ],
  "taskInterval": {
    "start": 681270022.377544,
    "duration": 0.42691
  },
  "redirectCount": 0
}
""".data(using: .utf8)!)

// MARK: - GitHub Profile (Failure, 404)

extension MockDataTask {
    static let profileFailure = MockDataTask(
        request: mockProfileFailureRequest,
        response: mockProfileFailureResponse,
        responseBody: """
        <h1>Error 404</h1>
        """.data(using: .utf8)!,
        metrics: mockMetrics
    )
}

private let mockProfileFailureRequest: URLRequest = {
    var request = URLRequest(url: URL(string: "https://github.com/profile/valdo")!)

    request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("github.com", forHTTPHeaderField: "Host")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.setValue("en-us", forHTTPHeaderField: "Accept-Language")
    request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

    return request
}()

private let mockProfileFailureResponse = HTTPURLResponse(url: URL(string: "https://github.com/profile/valdo")!, statusCode: 404, httpVersion: "2.0", headerFields: [
    "Content-Length": "18",
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Content-Encoding": "gzip",
    "Set-Cookie": "_device_id=11111111111; path=/; expires=Sun, 30 Jan 2022 21:49:04 GMT; secure; HttpOnly; SameSite=Lax"
])!

// MARK: - GitHub Octovat (Success, 200)

extension MockDataTask {
    static let octocat = MockDataTask(
        request: mockOctocatRequest,
        response: mockOctocatResponse,
        responseBody: mockImage,
        metrics: mockMetrics
    )
}

private let mockOctocatRequest: URLRequest = {
    var request = URLRequest(url: URL(string: "https://github.com/octocat.png")!)

    request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("github.com", forHTTPHeaderField: "Host")
    request.setValue("image/any", forHTTPHeaderField: "Content-Type")
    request.setValue("en-us", forHTTPHeaderField: "Accept-Language")

    return request
}()

private let mockOctocatResponse = HTTPURLResponse(url: URL(string: "https://github.com/octocat.png")!, statusCode: 302, httpVersion: "2.0", headerFields: [
    "Content-Length": "21504",
    "Content-Type": "image/png",
    "Cache-Control": "public, max-age=3600",
    "Expires": "Mon, 26 Feb 2021 17:45:57 GMT",
    "Last-Modified": "Mon, 12 Jan 2016 17:45:57 GMT",
    "ETag": "686897696a7c876b7e",
    "Content-Encoding": "gzip"
])!

// MARK: - GitHub Stats (Network Error)

let mockStatsFailureRequest: URLRequest = {
    var request = URLRequest(url: URL(string: "https://github.com/stats")!)

    request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("github.com", forHTTPHeaderField: "Host")

    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.setValue("en-us", forHTTPHeaderField: "Accept-Language")
    request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

    return request
}()

// MARK: - JSON (Mocks)

struct MockJSON {
    static let githubLoginResponse = """
    {
        "access-token": "a1",
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

    static let allPossibleValues = """
    {
      "actors": [
        {
          "name": "Tom Cruise",
          "age": 56,
          "Born At": "Syracuse, NY",
          "Birthdate": "July 3, 1962",
          "photo": "https://jsonformatter.org/img/tom-cruise.jpg",
          "wife": null,
          "weight": 67.5,
          "hasChildren": true,
          "hasGreyHair": false,
          "children": [
            "Suri",
            "Isabella Jane",
            "Connor"
          ]
        },
        {
          "name": "Robert Downey Jr.",
          "age": 53,
          "born At": "New York City, NY",
          "birthdate": "April 4, 1965",
          "photo": "https://jsonformatter.org/img/Robert-Downey-Jr.jpg",
          "wife": "Susan Downey",
          "weight": 77.1,
          "hasChildren": true,
          "hasGreyHair": false,
          "children": [
            "Indio Falconer",
            "Avri Roel",
            "Exton Elias"
          ]
        }
      ]
    }
    """.data(using: .utf8)!
}

// MARK: - Images (Mocks)

let mockImage = Data(base64Encoded: "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")!
