import SwiftUI

struct AmbulandoIcon: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.6, green: 0.1, blue: 0.6),
                    Color(red: 0.5, green: 0.05, blue: 0.5),
                    Color(red: 0.7, green: 0.15, blue: 0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Main footprint
            FootprintShape()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.65, height: size * 0.75)
                .rotationEffect(.degrees(-15))
                .offset(x: -size * 0.05, y: -size * 0.05)
            
            // Shadow footprint for depth
            FootprintShape()
                .fill(Color(red: 0.4, green: 0.05, blue: 0.4).opacity(0.3))
                .frame(width: size * 0.65, height: size * 0.75)
                .rotationEffect(.degrees(-15))
                .offset(x: -size * 0.03, y: -size * 0.03)
                .blur(radius: size * 0.02)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237))
    }
}

// Preview for development
struct AmbulandoIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AmbulandoIcon(size: 180)
            AmbulandoIcon(size: 120)
            AmbulandoIcon(size: 60)
        }
        .padding()
        .background(Color.gray)
    }
}