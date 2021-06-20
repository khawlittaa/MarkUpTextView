//
//  MarkUPTextViewModel.swift
//  MarkUpText
//
//  Created by khaoula hafsia on 20/6/2021.
//

import SwiftUI
import Combine

struct MDTextGroup {
    var string: String
    var rules: [MarkdownRule]
    var applicableRules: [MarkdownRule] {
        rules.filter{$0.regex != BaseMarkdownRules.none.regex}
    }
    var text: Text {
        guard let firstRule = applicableRules.first else { return rules[0].regex.output(for: string) }
        return applicableRules.dropFirst().reduce(firstRule.regex.output(for: string)) { $1.regex.strategy($0) }
    }
    
    var viewType: MDViewType {
        applicableRules.contains(where: { $0.id == BaseMarkdownRules.link.id || $0.id == BaseMarkdownRules.hyperlink.id }) ?
            .link(self) : .text(self.text)
    }
    
    var urlStr: String {
        RegexMarkdown.url(for: string)
    }
    
}

enum MDViewType {
    case text(Text), link(MDTextGroup)
}

struct MDViewGroup: Identifiable {
    let id = UUID()
    var type: MDViewType
    var view: some View {
        switch type {
        case .link(let group):
            return Button(action: {self.onLinkTap(urlStr: group.urlStr)}, label: {group.text})
                .ereaseToAnyView()
        case .text(let text):
            return text.ereaseToAnyView()
        }
    }
    
    func onLinkTap(urlStr: String) {
        print(urlStr)
        guard let url = URL(string: urlStr) else { return }
        #if os(iOS)
        UIApplication.shared.open(url, options: [:])
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}


extension View {
    func ereaseToAnyView() -> AnyView {
        AnyView(self)
    }
}

final  class MarkUPTextViewModel: ObservableObject {
    
    @Published var finalText = Text("")
    
    var cancellable: Cancellable? = nil { didSet{ oldValue?.cancel() } }
    
    func parse(string: String, for markdownRules: [MarkdownRule]) {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        cancellable = Just(markdownRules)
            .map{ rules -> [MDTextGroup] in
                rules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
                    return result.flatMap{ self.replace(group: $0, for: rule)}
                }
        }
        .map { textGroups in
            textGroups.map{ $0.text}.reduce(Text(""), +)
        }
        .receive(on: RunLoop.main)
        .assign(to: \.finalText, on: self)
    }
    
    func parseText(string: String, for markdownRules: [MarkdownRule]) -> Text {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        let textGroups = markdownRules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
            return result.flatMap{ self.replace(group: $0, for: rule)}
        }
        return textGroups.map{ $0.text}.reduce(Text(""), +)
    }
    
    func parseViews(string: String, for markdownRules: [MarkdownRule]) -> [MDViewGroup] {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        let textGroups = markdownRules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
            return result.flatMap{ self.replace(group: $0, for: rule)}
        }
        
        guard let firstViewGroup = textGroups.first?.viewType else { return [] }
        
        let allViewGroups = textGroups.dropFirst().reduce([MDViewGroup(type: firstViewGroup)]) { (viewGroups, textGroup) -> [MDViewGroup] in
            let previous = viewGroups.last!
            if case .text(let previousText) = previous.type, case .text(let currentText) = textGroup.viewType {
                let updatedText = previousText + currentText
                return viewGroups.dropLast() + [MDViewGroup(type: .text(updatedText))]
            } else {
                return viewGroups + [MDViewGroup(type: textGroup.viewType)]
            }
            // if previous is just text
        }
        return allViewGroups
    }
    
    func replaceLInk(for textGroup: MDTextGroup) -> AnyView {
        return Button(action: {
            guard let url = URL(string: textGroup.string) else { return }
            #if os(iOS)
            UIApplication.shared.open(url, options: [:])
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }, label: {textGroup.text})
            .ereaseToAnyView()
    }
    
    func replace(group: MDTextGroup, for rule: MarkdownRule) -> [MDTextGroup] {
        let string = group.string
        guard let regex = try? NSRegularExpression(pattern: rule.regex.matchIn)
            else {
                return [group]
        }
        let matches = regex.matches(in: string, range: NSRange(0..<string.utf16.count))
        let ranges = matches.map{ $0.range}
        guard !ranges.isEmpty else {
            return [group]
        }
        let zippedRanges = zip(ranges.dropFirst(), ranges)
        // TODO: pass parent modifiers to children, just create a func in mdtextgroup
        let beforeMatchesGroup = ranges.first.flatMap { range -> [MDTextGroup] in
            let lowerBound = String.Index(utf16Offset: 0, in: string)
            let upperBound = String.Index(utf16Offset: range.lowerBound, in: string)
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            return [MDTextGroup(string: nonMatchStr, rules: group.rules)]
            } ?? []
        
        let resultGroups: [MDTextGroup] =  zippedRanges.flatMap{ (next, current) -> [MDTextGroup] in
            guard let range = Range(current, in: string) else { return [] }
            let matchStr = String(string[range])

            let lowerBound = String.Index(utf16Offset: current.upperBound, in: string)
            let upperBound = String.Index(utf16Offset: next.lowerBound, in: string)
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            let groups = [MDTextGroup(string: matchStr, rules: group.rules + [rule]), MDTextGroup(string: nonMatchStr, rules: group.rules)]
            return groups
        }
        
        let lastMatch = ranges.last.flatMap{ range -> [MDTextGroup] in
            guard let index = Range(range, in: string) else { return [] }
            let matchStr = String(string[index])
            return [MDTextGroup(string: matchStr, rules: group.rules + [rule])]
            } ?? []
        
        let afterMatchesGroup = ranges.last.flatMap { range -> [MDTextGroup] in
            let lowerBound = String.Index(utf16Offset: range.upperBound, in: string)
            let upperBound = string.endIndex
            
            if upperBound <= lowerBound { // basically if it ends with a match.
                return []
            }
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            return [MDTextGroup(string: nonMatchStr, rules: group.rules)]
            } ?? []
        
        
        let completeGroups = beforeMatchesGroup + resultGroups + lastMatch + afterMatchesGroup
        return completeGroups
    }
    
}
