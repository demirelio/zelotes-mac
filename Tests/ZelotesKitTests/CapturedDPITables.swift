/// 64-byte DPI tables as the vendor's Windows software sent them.
enum CapturedDPITables {
    static let firstFactory = bytes(
        """
        0f 00 1e 0a 19 19 05 04 06 10 64 64 01 c0 f0 03
        01 01 19 19 22 39 5c d0 f3 5c 73 00 22 39 5c d0
        f3 5c 73 00 1f ff 00 00 31 00 00 00 31 00 00 00
        31 31 31 00 31 00 31 00 31 31 31 31 31 31 31 31
        """
    )

    static let secondFactory = bytes(
        """
        0f 00 1e 0a 19 19 05 01 01 03 64 64 01 c0 f0 03
        01 01 19 19 22 39 5c d0 f3 5c 73 00 22 39 5c d0
        f3 5c 73 00 1f ff 00 00 00 00 31 00 00 31 00 00
        31 00 00 31 00 00 31 00 00 31 00 00 31 00 00 31
        """
    )

    static let firstStageOneSetTo1000 = bytes(
        "0f001e0a191905040610646401c0f0030101191916395cd0f35c730016395cd0f35c73001fff0000310000003100000031313100310031003131313131313131"
    )

    static let thenStageThreeSetTo3000 = bytes(
        "0f001e0a191905040610646401c0f00301011919163945d0f35c7300163945d0f35c73001fff0000310000003100000031313100310031003131313131313131"
    )

    static let thenStageFourSetTo5000 = bytes(
        "0f001e0a191905040610646401c0f0030101191916394573f35c730016394573f35c73001fff0000310000003100000031313100310031003131313131313131"
    )

    static let thenStageFiveSetTo7000 = bytes(
        "0f001e0a191905040610646401c0f0030101191916394573d05c730016394573d05c73001fff0000310000003100000031313100310031003131313131313131"
    )

    private static func bytes(_ hex: String) -> [UInt8] {
        let digits = hex.filter(\.isHexDigit)
        var result: [UInt8] = []
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            result.append(UInt8(digits[index..<next], radix: 16)!)
            index = next
        }
        return result
    }
}
