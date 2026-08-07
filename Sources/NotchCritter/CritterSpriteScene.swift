import SpriteKit

/// Loads the per-mood frame sequences bundled as SPM resources and drives
/// the looping animation for whichever mood is currently active.
final class CritterSpriteScene: SKScene {
    private let spriteNode = SKSpriteNode()
    private var textureCache: [CritterMood: [SKTexture]] = [:]
    private var currentMood: CritterMood?

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
            textureCache[mood] = loadTextures(for: mood)
        }
    }

    private func loadTextures(for mood: CritterMood) -> [SKTexture] {
        let name: String
        switch mood {
        case .idle: name = "idle"
        case .alert: name = "alert"
        case .sleepy: name = "sleepy"
        }
        return (0..<4).compactMap { frame -> SKTexture? in
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
        let timePerFrame: TimeInterval = mood == .alert ? 0.12 : 0.22
        let animation = SKAction.animate(with: textures, timePerFrame: timePerFrame, resize: false, restore: true)
        spriteNode.run(.repeatForever(animation))
    }
}
