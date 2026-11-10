import Testing
import ZelotesKit

@Suite struct KeyboardKeyTests {
    @Test(arguments: [
        (KeyboardKey.a, "A"), (.d, "D"), (.s, "S"), (.w, "W"), (.space, "Space"), (.tab, "Tab"), (.f11, "F11"),
        (.upArrow, "↑"), (.downArrow, "↓"), (.leftArrow, "←"), (.rightArrow, "→"),
        (KeyboardKey(usage: 0x27), "0"), (KeyboardKey(usage: 0x45), "F12"), (KeyboardKey(usage: 0x68), "F13"),
    ])
    func aKeyIsNamedAfterItsUsage(key: KeyboardKey, name: String) {
        #expect(key.name == name)
    }

    @Test func aKeyOutsideTheCatalogIsNamedByItsUsage() {
        #expect(KeyboardKey(usage: 0xE0).name == "Key 224")
    }

    @Test func everyKeyInTheCatalogHasItsOwnUsage() {
        let usages = KeyboardKey.groups.flatMap(\.keys).map(\.usage)

        #expect(Set(usages).count == usages.count)
    }
}
