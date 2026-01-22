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
            ZStack {
                // Completely transparent background covering full screen
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Character View - now covering full screen for 3D coordinate mapping
                CharacterView(size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
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