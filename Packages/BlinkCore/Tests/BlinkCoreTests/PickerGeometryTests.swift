import CoreGraphics
import Testing
@testable import BlinkCore

@Suite("Picker placement")
struct PickerPlacementTests {
    // A laptop screen with a 25-point menu bar and an 80-point Dock, and an external display to its right.
    let laptop = PickerPlacement.Screen(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 80, width: 1512, height: 877)
    )
    let external = PickerPlacement.Screen(
        frame: CGRect(x: 1512, y: -200, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1512, y: -200, width: 2560, height: 1415)
    )
    let size = CGSize(width: 340, height: 400)

    @Test func centersBelowThePointer() {
        let frame = PickerPlacement.frame(size: size, pointer: CGPoint(x: 700, y: 700), screens: [laptop, external])
        #expect(frame == CGRect(x: 530, y: 324, width: 340, height: 400))
    }

    @Test func staysBelowTheMenuBarAndAboveTheDock() {
        let top = PickerPlacement.frame(size: size, pointer: CGPoint(x: 700, y: 980), screens: [laptop])
        #expect(top.maxY == laptop.visibleFrame.maxY - PickerPlacement.margin)
        let bottom = PickerPlacement.frame(size: size, pointer: CGPoint(x: 700, y: 90), screens: [laptop])
        #expect(bottom.minY == laptop.visibleFrame.minY + PickerPlacement.margin)
    }

    @Test func staysOnScreenAtHorizontalEdges() {
        let left = PickerPlacement.frame(size: size, pointer: CGPoint(x: 2, y: 500), screens: [laptop])
        #expect(left.minX == PickerPlacement.margin)
        let right = PickerPlacement.frame(size: size, pointer: CGPoint(x: 1510, y: 500), screens: [laptop, external])
        #expect(right.maxX == laptop.visibleFrame.maxX - PickerPlacement.margin)
    }

    @Test func usesTheScreenUnderThePointer() {
        let frame = PickerPlacement.frame(size: size, pointer: CGPoint(x: 3000, y: -150), screens: [laptop, external])
        #expect(external.visibleFrame.contains(frame))
        #expect(frame.minY == external.visibleFrame.minY + PickerPlacement.margin)
    }

    @Test func shrinksWhenTheScreenIsTooSmall() {
        let tiny = PickerPlacement.Screen(frame: CGRect(x: 0, y: 0, width: 300, height: 300), visibleFrame: CGRect(x: 0, y: 0, width: 300, height: 280))
        let frame = PickerPlacement.frame(size: size, pointer: CGPoint(x: 150, y: 150), screens: [tiny])
        #expect(frame == CGRect(x: 8, y: 8, width: 284, height: 264))
    }

    @Test func fallsBackToTheFirstScreen() {
        let frame = PickerPlacement.frame(size: size, pointer: CGPoint(x: -5000, y: 0), screens: [laptop])
        #expect(laptop.visibleFrame.contains(frame))
        #expect(PickerPlacement.frame(size: size, pointer: .zero, screens: []).size == size)
    }
}

@Suite("Picker keys")
struct PickerKeyTests {
    @Test func mapsPhysicalKeys() {
        #expect(PickerKey(keyCode: 126, hasCommandModifier: false) == .up)
        #expect(PickerKey(keyCode: 125, hasCommandModifier: false) == .down)
        #expect(PickerKey(keyCode: 124, hasCommandModifier: false) == .expand)
        #expect(PickerKey(keyCode: 123, hasCommandModifier: false) == .collapse)
        #expect(PickerKey(keyCode: 124, hasCommandModifier: true) == nil)
        #expect(PickerKey(keyCode: 36, hasCommandModifier: false) == .open)
        #expect(PickerKey(keyCode: 76, hasCommandModifier: false) == .open)
        #expect(PickerKey(keyCode: 18, hasCommandModifier: false) == .digit(1))
        #expect(PickerKey(keyCode: 25, hasCommandModifier: false) == .digit(9))
        #expect(PickerKey(keyCode: 89, hasCommandModifier: false) == .digit(7))
    }

    @Test func ignoresOtherKeysAndShortcuts() {
        #expect(PickerKey(keyCode: 29, hasCommandModifier: false) == nil) // 0
        #expect(PickerKey(keyCode: 0, hasCommandModifier: false) == nil)
        #expect(PickerKey(keyCode: 18, hasCommandModifier: true) == nil)
        #expect(PickerKey(keyCode: 36, hasCommandModifier: true) == nil)
    }
}
