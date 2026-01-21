//
//  OverlayView.swift
//  mac-pet
//
//  Created by Anurag singh on 21/01/26.
//

import SwiftUI

struct OverlayView: View {
    var body: some View {
        ZStack {
            // Completely transparent background
            Color.clear
            
            // Character View
            CharacterView()
                .frame(width: 300, height: 300)
                .position(x: NSScreen.main?.frame.width ?? 500 / 2, y: (NSScreen.main?.frame.height ?? 500) - 150)
            
            // Centered text (optional, for debugging)
            // Text("HELLO OVERLAY")
            //    .font(.system(size: 72, weight: .bold))
            //    .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    OverlayView()
}