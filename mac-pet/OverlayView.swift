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
            
            // Centered text
            Text("HELLO OVERLAY")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    OverlayView()
}
