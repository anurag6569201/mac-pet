//
//  OverlayView.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import SwiftUI

struct OverlayView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Completely transparent background covering full screen
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Character View - aligned to bottom trailing with no padding
                CharacterView()
                    .frame(width: 300, height: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea(.all)
    }
}

#Preview {
    OverlayView()
}