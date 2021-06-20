//
//  MarkdownText.swift
//  MarkUpText
//
//  Created by khaoula hafsia on 20/6/2021.
//

import Foundation
import SwiftUI

struct RegexMarkdown: Equatable {
    static func == (lhs: RegexMarkdown, rhs: RegexMarkdown) -> Bool {
        lhs.matchIn == rhs.matchIn && lhs.matchOut == rhs.matchOut
    }
    
    var matchIn: String
    var matchOut: String
    var strategy: (Text) -> Text
    func output(for string: String) -> Text {
        let result = outputString(for: string)
        let text = Text(result)
        return strategy(text)
    }
    
    func outputString(for string: String) -> String {
        guard !matchIn.isEmpty else {
            return string
        }
        return string.replacingOccurrences(of: self.matchIn, with: self.matchOut, options: .regularExpression)
    }
    
    static func url(for string: String) -> String {
        let matcher = try! NSRegularExpression(pattern: #"((http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))"#)
        guard let match = matcher.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)) else { return ""}
        let result = string[Range(match.range, in: string)!]
        print(result)
        return String(result)
    }
}

extension RegexMarkdown {
    private var matcher: NSRegularExpression {
        return try! NSRegularExpression(pattern: self.matchIn)
        
    }
    func match(string: String, options: NSRegularExpression.MatchingOptions = .init()) -> Bool {
        return self.matcher.numberOfMatches(in: string, options: options, range: NSMakeRange(0, string.utf16.count)) != 0
    }
}

protocol MarkdownRule {
    var id: String { get }
    var regex: RegexMarkdown { get }
    //    func replace(_ text: String) -> Text
}

public enum BaseMarkdownRules: String, CaseIterable, MarkdownRule{
    
    
    case none, header, link, bold, hyperlink, italic
    var id: String { self.rawValue }
    //
    //    , , del, quote, inline, ul, ol, blockquotes
    
    var regex: RegexMarkdown {
        switch self {
        case .header:
            return .init(matchIn: #"(#+)(.*)"#, matchOut: "$2", strategy: self.header(_:))
        case .link:
            return .init(matchIn: #"\[([^\[]+)\]\(([^\)]+)\)"#, matchOut: "$1", strategy: self.link(_:))
        case .bold:
            return .init(matchIn: #"(\*\*|__)(.*?)\1"#, matchOut: "$2", strategy: self.bold(_:))
        case .hyperlink:
            return .init(matchIn: "<((?i)https?://(?:www\\.)?\\S+(?:/|\\b))>", matchOut: "$1", strategy: self.link(_:))
        case .italic:
            return .init(matchIn: #"(\s)(\*|_)(.+?)\2"#, matchOut: "$1$3", strategy: self.italic(_:))
        case .none:
            return .init(matchIn: "", matchOut: "", strategy: {$0})
        }
    }
    
    func header(_ text: Text) -> Text {
        return text.font(.headline)
    }
    
    func link(_ text: Text) -> Text {
        return text.foregroundColor(.blue)
    }
    
    func bold(_ text: Text) -> Text {
        return text.bold()
    }
    
    func italic(_ text: Text) -> Text {
        return text.italic()
    }
}
