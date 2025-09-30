import SwiftUI
import AVFoundation

// MARK: - Screen Enum
enum Screen {
    case onboarding
    case game
}

// MARK: - Audio Manager
final class AudioManager {
    static let shared = AudioManager()
    private var loopPlayers: [String: AVAudioPlayer] = [:]
    private var activePlayers: [AVAudioPlayer] = []

    func playLooped(named filename: String,
                    fileExtension: String,
                    volume: Float = 0.8,
                    respectSilentSwitch: Bool = true) {
        let key = filename + "." + fileExtension
        if loopPlayers[key] != nil { return }
        guard let url = Bundle.main.url(forResource: filename, withExtension: fileExtension) else { return }
        do {
            let category: AVAudioSession.Category = respectSilentSwitch ? .ambient : .playback
            try AVAudioSession.sharedInstance().setCategory(category, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = volume
            player.prepareToPlay()
            player.play()
            loopPlayers[key] = player
        } catch { print("⚠️ Loop audio error: \(error.localizedDescription)") }
    }

    func fadeOutAllLoops(duration: TimeInterval = 0.4) {
        for (key, player) in loopPlayers {
            let steps = 8
            let stepDuration = duration / Double(steps)
            let startVolume = player.volume
            for i in 1...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                    player.volume = max(0, startVolume * Float(steps - i) / Float(steps))
                    if i == steps {
                        player.stop()
                        self?.loopPlayers.removeValue(forKey: key)
                    }
                }
            }
        }
    }

    func stopLoop(named filename: String, fileExtension: String) {
        let key = filename + "." + fileExtension
        if let player = loopPlayers[key] {
            player.stop()
            loopPlayers.removeValue(forKey: key)
        }
    }

    func playOneShot(named filename: String, fileExtension: String, volume: Float = 1.0) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: fileExtension) else { return }
        do {
            let sfx = try AVAudioPlayer(contentsOf: url)
            sfx.volume = volume
            sfx.prepareToPlay()
            sfx.play()
            activePlayers.append(sfx)
            sfx.delegate = OneShotDelegate { [weak self, weak sfx] in
                if let sfx, let idx = self?.activePlayers.firstIndex(of: sfx) {
                    self?.activePlayers.remove(at: idx)
                }
            }
        } catch { print("⚠️ One-shot audio error: \(error.localizedDescription)") }
    }

    func stopAllOneShots() {
        for player in activePlayers {
            player.stop()
        }
        activePlayers.removeAll()
    }
}

private class OneShotDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { onFinish() }
}

// MARK: - Duck Model
struct Duck: Identifiable {
    let id = UUID()
    var position: CGPoint
    var angle: Double = Double.random(in: -25...25)
    var flipped: Bool = Bool.random()
    var size: CGFloat = CGFloat.random(in: 40...70)
}

// MARK: - MultiTouch
final class MultiTouchView: UIView {
    var onTouchesBegan: ((Set<UITouch>, UIEvent?) -> Void)?
    var onTouchesMoved: ((Set<UITouch>, UIEvent?) -> Void)?
    var onTouchesEnded: ((Set<UITouch>, UIEvent?) -> Void)?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { onTouchesBegan?(touches, event) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { onTouchesMoved?(touches, event) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { onTouchesEnded?(touches, event) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { onTouchesEnded?(touches, event) }
}

struct MultiTouchViewRepresentable: UIViewRepresentable {
    var onTouchesBegan: ((Set<UITouch>, UIEvent?) -> Void)?
    var onTouchesMoved: ((Set<UITouch>, UIEvent?) -> Void)?
    var onTouchesEnded: ((Set<UITouch>, UIEvent?) -> Void)?
    func makeUIView(context: Context) -> MultiTouchView {
        let v = MultiTouchView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        v.onTouchesBegan = onTouchesBegan
        v.onTouchesMoved = onTouchesMoved
        v.onTouchesEnded = onTouchesEnded
        return v
    }
    func updateUIView(_ uiView: MultiTouchView, context: Context) {}
}

// MARK: - Ripple
struct RippleView: View {
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0.6
    var body: some View {
        Circle()
            .stroke(Color.blue.opacity(opacity), lineWidth: 3)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) {
                    scale = 2.5
                    opacity = 0
                }
            }
    }
}

// MARK: - DuckView
struct DuckView: View {
    let duck: Duck
    @State private var bobbing = false
    @State private var splash = true
    @State private var wobble = false
    var body: some View {
        Image("rubber_duck")
            .resizable()
            .scaledToFit()
            .frame(width: duck.size, height: duck.size)
            .scaleEffect(x: duck.flipped ? -1 : 1, y: 1)
            .rotationEffect(.degrees(duck.angle + (wobble ? 2.0 : -2.0)))
            .scaleEffect(splash ? 1.25 : 1.0)
            .offset(y: bobbing ? -6 : 6)
            .animation(
                splash
                ? .easeOut(duration: 0.28)
                : .easeInOut(duration: Double.random(in: 1.6...2.4)).repeatForever(autoreverses: true),
                value: splash ? splash : bobbing
            )
            .animation(
                splash
                ? .default
                : .easeInOut(duration: Double.random(in: 1.4...2.0)).repeatForever(autoreverses: true),
                value: wobble
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    splash = false
                    bobbing.toggle()
                    wobble.toggle()
                }
            }
    }
}

// MARK: - Game Screen
struct GameView: View {
    @State private var ducks: [Duck] = []
    @State private var ripples: [UUID: CGPoint] = [:]
    @State private var activeTouches: [UITouch: CGPoint] = [:]
    @State private var gameOver = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()

                // Bathtub dimensions
                let tubWidth = min(geo.size.width * 0.92, 1000)
                let tubHeight = tubWidth * 2.0
                let tubCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                Image("bathtub")
                    .resizable()
                    .scaledToFit()
                    .frame(width: tubWidth)
                    .position(x: geo.size.width/2, y: geo.size.height/2)
                    .allowsHitTesting(false)

                // Ripples
                ForEach(Array(ripples.keys), id: \.self) { id in
                    if let pos = ripples[id] {
                        RippleView()
                            .frame(width: 90, height: 90)
                            .position(pos)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    ripples.removeValue(forKey: id)
                                }
                            }
                    }
                }

                // Ducks
                ForEach(ducks) { duck in
                    DuckView(duck: duck)
                        .position(duck.position)
                }

                // Ghost ducks while finger is held
                ForEach(Array(activeTouches.values), id: \.self) { pos in
                    Image("rubber_duck")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 55, height: 55)
                        .opacity(0.5)
                        .position(pos)
                }

                // Touch handler
                MultiTouchViewRepresentable(
                    onTouchesBegan: { touches, _ in
                        for t in touches { activeTouches[t] = t.location(in: t.view) }
                    },
                    onTouchesMoved: { touches, _ in
                        for t in touches { activeTouches[t] = t.location(in: t.view) }
                    },
                    onTouchesEnded: { touches, _ in
                        for t in touches {
                            if let p = activeTouches[t] {
                                // === ELLIPSE CHECK (bathtub water zone) ===
                                let tubRadiusX = tubWidth / 2.1
                                let tubRadiusY = tubHeight / 2.1
                                let dx = (p.x - tubCenter.x) / tubRadiusX
                                let dy = (p.y - tubCenter.y) / tubRadiusY
                                let insideOval = (dx * dx + dy * dy) <= 1.0
                                // =========================================

                                if insideOval {
                                    let duck = Duck(position: p)
                                    ducks.append(duck)
                                    ripples[duck.id] = p
                                    AudioManager.shared.playOneShot(named: "Duck-Drop", fileExtension: "wav")
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred() // ✅ haptic for success
                                } else {
                                    if !gameOver {
                                        AudioManager.shared.playOneShot(named: "Game-over", fileExtension: "wav")
                                        AudioManager.shared.playLooped(named: "distortion", fileExtension: "wav", volume: 0.9)
                                        UINotificationFeedbackGenerator().notificationOccurred(.error) // ✅ haptic for fail
                                    }
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        gameOver = true
                                    }
                                }
                            }
                            activeTouches.removeValue(forKey: t)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())

                // GAME OVER overlay
                if gameOver {
                    Color.black.opacity(0.75).ignoresSafeArea()
                        .onTapGesture {
                            AudioManager.shared.stopLoop(named: "distortion", fileExtension: "wav")
                            AudioManager.shared.stopAllOneShots()
                            ducks.removeAll()
                            ripples.removeAll()
                            gameOver = false
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred() // ✅ haptic on restart
                        }

                    VStack(spacing: 20) {
                        Text("GAME OVER")
                            .font(.system(size: 56, weight: .heavy))
                            .foregroundColor(.red)
                            .shadow(radius: 10)

                        Text("Tap to Restart")
                            .font(.title3)
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
        }
    }
}

// MARK: - Onboarding
struct OnboardingView: View {
    @Binding var currentScreen: Screen
    @State private var bob = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.25), .cyan.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Quack Splash")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                Image("rubber_duck")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .offset(y: bob ? -10 : 10)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: bob)
                Text("Add duckies. Make waves. Relax.")
                    .foregroundStyle(.white.opacity(0.9))
                    .font(.title3)
                Button {
                    let h = UIImpactFeedbackGenerator(style: .soft)
                    h.impactOccurred()
                    AudioManager.shared.fadeOutAllLoops()
                    withAnimation { currentScreen = .game }
                } label: {
                    Text("Let’s Go")
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.white)
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                }
            }
        }
        .onAppear {
            bob = true
            AudioManager.shared.playLooped(named: "Water-Drops", fileExtension: "wav", volume: 0.6)
            AudioManager.shared.playLooped(named: "Onboarding-Theme", fileExtension: "wav", volume: 0.8)
        }
        .onDisappear { AudioManager.shared.fadeOutAllLoops() }
    }
}

// MARK: - Root
struct ContentView: View {
    @State private var currentScreen: Screen = .onboarding
    var body: some View {
        switch currentScreen {
        case .onboarding: OnboardingView(currentScreen: $currentScreen)
        case .game: GameView()
        }
    }
}

#Preview { ContentView() }
