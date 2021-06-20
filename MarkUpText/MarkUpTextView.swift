//
//  MarkUpTextView.swift
//  MarkUpText
//
//  Created by khaoula hafsia on 20/6/2021.
//

import SwiftUI

public struct MarkUpTextView: View, Equatable {
    
    public static func == (lhs: MarkUpTextView, rhs: MarkUpTextView) -> Bool {
        lhs.markdown == rhs.markdown
    }
    
    var markdown: String
    var alignment: HorizontalAlignment
    
    var rules: [MarkdownRule] = BaseMarkdownRules.allCases
    
    @ObservedObject var vm = MarkUPTextViewModel()
    
    public init(markdown: String, alignment: HorizontalAlignment = .leading) {
        self.markdown = markdown
        self.alignment = alignment
    }
    
    var views: [MDViewGroup] {
        vm.parseViews(string: markdown, for: rules)
    }
    
    public var body: some View {
        VStack(alignment: alignment) {
            HStack { Spacer() }
            //            vm.parseText(string: markdown, for: rules)
            ForEach(self.views, id: \.id) { viewGroup in
                viewGroup.view
            }
        }
        //        .onAppear(perform: parse)
    }
    
    //    func parse() {
    //        vm.parse(string: markdown, for: rules)
    //    }
}



struct MarkUpTextView_Previews: PreviewProvider {
    static var previews: some View {
        MarkUpTextView(markdown: "__TEXT BOLD__ and other _ItalicVariation_ here")
    }
}
