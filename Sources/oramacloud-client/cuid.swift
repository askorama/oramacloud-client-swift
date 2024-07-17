//
//  Cuid.swift
//  cuid
//
//  Created by Raphael MANSUY on 13/05/2018.
//  based on Eric Elliott 2012 cuid Javascript
//  MIT License
//

import Foundation

extension StringProtocol {
  var ascii: [UInt32] {
    return unicodeScalars.filter{$0.isASCII}.map{$0.value}
  }
}

extension Character {
  var ascii: UInt32? {
    return String(self).unicodeScalars.filter{$0.isASCII}.first?.value
  }
}

struct Fingerprint {
  private static let convertBase = 36
  
  static func generate() -> String {
    let padding = 2
    let pid = String(getpid(),radix: convertBase).padding(toLength: padding, withPad: "0", startingAt: 0)
    let idDevice = UUID.deviceUUID()
    let idDeviceLength = idDevice.count
    let idDeviceCode = idDevice.ascii.reduce(UInt32(idDeviceLength+convertBase), { $0 + $1 })
    let hostId = String(idDeviceCode,radix:convertBase).padding(toLength: padding, withPad: "0", startingAt: 0)
    let fingerprint = pid + hostId
    return fingerprint
  }
}

public struct Cuid {
  private static var c = 0
  private static let blocksize = 4
  private static let convertBase = 36
  private static let discreteValues: Decimal = pow(Decimal(convertBase),blocksize)
  
  static func randomBloc() -> String {
    let d = NSDecimalNumber(decimal: discreteValues)
    let r = arc4random_uniform(UInt32(truncating: d)) << 0
    let radix = String(r,radix: convertBase)
    return radix.padding(toLength: blocksize, withPad: "0", startingAt: 0)
  }
  
  static func safeCounter() -> Int {
    let dvals = Int(truncating: NSDecimalNumber(decimal: discreteValues))
    c = c < dvals ? c : 0
    c = c + 1; // this is not subliminal
    return c - 1
  }
  
  @discardableResult
  public static func generateId() -> String {
    // Starting with a lowercase letter makes
    // it HTML element ID friendly.
    let letter = "c" // hard-coded allows for sequential access
    // timestamp
    let timestamp =  String(Int64(Date().timeIntervalSince1970 * 1000),radix:convertBase)
    // Prevent same-machine collisions
    let counter = String(safeCounter(),radix:convertBase).padding(toLength: blocksize, withPad: "0", startingAt: 0)
    let print = Fingerprint.generate()
    let random = randomBloc() + randomBloc()
    let cuid = letter + timestamp + counter + print + random
    return cuid
  }
}
