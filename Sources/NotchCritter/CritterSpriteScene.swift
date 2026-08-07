import SpriteKit

/// Loads the per-mood frame sequences bundled as SPM resources and drives
/// the looping animation for whichever mood is currently active.
final class CritterSpriteScene: SKScene {
    private let spriteNode = SKSpriteNode()
    private var textureCache: [CritterMood: [SKTexture]] = [:]
    private var yawnTextures: [SKTexture] = []
    private var currentMood: CritterMood?

    private static let loopActionKey = "loop"
    private static let yawnSchedulerActionKey = "yawnScheduler"
    private static let yawnPauseRange: ClosedRange<TimeInterval> = 5...10

    override init() {
        super.init(size: CGSize(width: 240, height: 240))
        scaleMode = .aspectFit
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        spriteNode.position = CGPoint(x: 0, y: 0)
        addChild(spriteNode)
        preloadTextures()
        update(mood: currentMood ?? .idle)
    }

    private func preloadTextures() {
        for mood in [CritterMood.idle, .alert, .sleepy] {
            textureCache[mood] = loadFrames(named: name(for: mood))
        }
        yawnTextures = loadFrames(named: "yawn")
    }

    private func name(for mood: CritterMood) -> String {
        switch mood {
        case .idle: return "idle"
        case .alert: return "alert"
        case .sleepy: return "sleepy"
        }
    }

    private func loadFrames(named name: String) -> [SKTexture] {
        (0..<4).compactMap { frame -> SKTexture? in
            guard let url = Self.imageURL(named: "\(name)_\(frame)"),
                  let image = NSImage(contentsOf: url) else { return nil }
            let texture = SKTexture(image: image)
            texture.filteringMode = .nearest
            return texture
        }
    }

    private static func imageURL(named name: String) -> URL? {
        let candidateSubdirectories: [String?] = ["Resources/Sprites", "Sprites", nil]
        for subdirectory in candidateSubdirectories {
            if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    /// Switches the looping animation to match `mood`. No-op if already
    /// showing that mood, so Combine updates that fire redundantly don't
    /// restart the loop and cause a visible stutter.
    func update(mood: CritterMood) {
        guard mood != currentMood else { return }
        guard let textures = textureCache[mood], !textures.isEmpty else { return }
        currentMood = mood

        if spriteNode.size == .zero, let first = textures.first {
            spriteNode.size = first.size()
        }

        spriteNode.removeAllActions()
        runLoop(textures: textures, timePerFrame: mood == .alert ? 0.12 : 0.22)

        if mood == .idle {
            scheduleYawn(idleTextures: textures)
        }
    }

    private func runLoop(textures: [SKTexture], timePerFrame: TimeInterval) {
        let animation = SKAction.animate(with: textures, timePerFrame: timePerFrame, resize: false, restore: true)
        spriteNode.run(.repeatForever(animation), withKey: Self.loopActionKey)
    }

    /// Runs alongside the idle loop (separate action key) and, every so
    /// often, swaps in the yawn frames for one pass before resuming the
    /// idle loop. Bails out if the mood has since changed, since
    /// `update(mood:)` already tore this scheduler down via
    /// removeAllActions() in that case — the check just guards the brief
    /// window where a pending action fires right as that happens.
    private func scheduleYawn(idleTextures: [SKTexture]) {
        guard !yawnTextures.isEmpty else { return }

        let wait = SKAction.wait(forDuration: .random(in: Self.yawnPauseRange))
        let playYawn = SKAction.run { [weak self] in
            guard let self, self.currentMood == .idle else { return }
            let yawn = SKAction.animate(with: self.yawnTextures, timePerFrame: 0.18, resize: false, restore: false)
            let resumeIdle = SKAction.run { [weak self] in
                guard let self, self.currentMood == .idle else { return }
                self.runLoop(textures: idleTextures, timePerFrame: 0.22)
            }
            self.spriteNode.run(.sequence([yawn, resumeIdle]), withKey: Self.loopActionKey)
        }
        spriteNode.run(.repeatForever(.sequence([wait, playYawn])), withKey: Self.yawnSchedulerActionKey)
    }
}
