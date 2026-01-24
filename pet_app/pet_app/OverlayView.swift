//
//  OverlayView.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import SwiftUI

struct OverlayView: View {
    let desktopCount: Int
    let desktopIndex: Int
    let screenSize: CGSize // We need actual screen size for camera setup
    
    var body: some View {
        GeometryReader { geometry in
            // No more ZStack with offset.
            // Just the CharacterView which will handle its own camera.
            // We pass the screen size and index so CharacterView can setup the correct camera.
            
            CharacterView(size: screenSize, desktopIndex: desktopIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.opacity(0.1)) // Red background with 0.1 opacity
        .ignoresSafeArea(.all)
    }
}

#Preview {
    OverlayView(desktopCount: 3, desktopIndex: 0, screenSize: CGSize(width: 1440, height: 900))
}