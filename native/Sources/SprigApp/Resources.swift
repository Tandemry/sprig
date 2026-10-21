import Foundation

extension Bundle {
  static var sprigResources: Bundle {
    #if SWIFT_PACKAGE
      return .module
    #else
      return .main
    #endif
  }
}
