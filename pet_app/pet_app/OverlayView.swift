//
//  OverlayView.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import SwiftUI

struct OverlayView: View {
    let desktopCount: Int
    let xOffset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let fullWidth = screenWidth * CGFloat(desktopCount)
            
            ZStack {
                // Red background with 0.1 opacity covering full extended width
                Color.red.opacity(0.1)
                    .frame(width: fullWidth, height: geometry.size.height)
                    .offset(x: xOffset)
                
                // Character View - covering full extended width for 3D coordinate mapping
                CharacterView(size: CGSize(width: fullWidth, height: geometry.size.height))
                    .frame(width: fullWidth, height: geometry.size.height)
                    .offset(x: xOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.opacity(0.1))
        .clipped() // Overflow hidden
        .ignoresSafeArea(.all)
    }
}

#Preview {
    OverlayView(desktopCount: 3, xOffset: 0)
}