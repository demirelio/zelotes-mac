import IOKit
import Testing
import ZelotesKit

@Suite struct MouseAccessErrorTests {
    @Test func anUnconfirmedWriteShowsTheStatusReportAsHexBytes() {
        let error = MouseAccessError.writeNotConfirmed(status: [0x0D, 0x01, 0x80, 0, 0, 0, 0, 0xAB])

        #expect(
            error.errorDescription == "The mouse did not confirm the write (status 0d 01 80 00 00 00 00 ab). "
                + "If the pointer is frozen, unplug the mouse and plug it back in."
        )
    }

    @Test func anIOKitFailureShowsItsReturnCodeInHex() {
        #expect(
            MouseAccessError.accessRefused(kIOReturnNotPermitted).errorDescription
                == "macOS refused access to the mouse (0xe00002e2)."
        )
        #expect(
            MouseAccessError.reportRejected(kIOReturnNoDevice).errorDescription
                == "The mouse did not accept the data (0xe00002c0)."
        )
    }
}
