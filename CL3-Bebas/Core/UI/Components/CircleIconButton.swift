//
//  MainCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 05/06/26.
//

import SwiftUI

struct CircleIconButton: View {
    var body : some View {
        ZStack {
            Button(action: {}) {
                ZStack {
                    // Lapisan Bawah: Lingkaran sebagai backdrop
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 60, height: 60)
                    
                    // Lapisan Atas: Ikon mikrofon
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .bold))
                }
            }
        }
    }
}
