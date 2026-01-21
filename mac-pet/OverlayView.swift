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
                
                // SceneKit character view positioned in bottom-right corner
                // Adjust position and size as needed
                CharacterView()
                    .frame(width: 300, height: 300)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    OverlayView()
}
