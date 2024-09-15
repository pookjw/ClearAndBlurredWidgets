//
//  MyWidgetBundle.swift
//  MyWidget
//
//  Created by Jinwoo Kim on 9/15/24.
//

import WidgetKit
import SwiftUI

@main
struct MyWidgetBundle: WidgetBundle {
    init() {}
    
    @WidgetBundleBuilder
    var body: some Widget {
        MyNormalWidget()
        MyClearWidget()
        MyBlurWidget()
    }
}
