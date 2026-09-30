//
//  AliyunDriveModel.swift
//  Amperfy
//

import Foundation

struct AliyunDriveItem: Identifiable, Sendable {
  enum Kind: Sendable {
    case folder
    case audio
  }

  let driveID: String
  let fileID: String
  let name: String
  let kind: Kind
  let contentType: String?
  let size: Int64?

  var id: String { "\(driveID):\(fileID)" }
  var isFolder: Bool { kind == .folder }
}

@MainActor
protocol AliyunDriveProviding: AnyObject {
  var isConfigured: Bool { get }
  var isAuthorized: Bool { get }

  func authorize() async throws
  func list(parentFileID: String) async throws -> [AliyunDriveItem]
  func streamURL(for item: AliyunDriveItem) async throws -> URL
  func disconnect()
}

enum AliyunDriveError: LocalizedError {
  case missingAppID
  case invalidAudioItem

  var errorDescription: String? {
    switch self {
    case .missingAppID:
      "Aliyun Drive is not configured. Set ALIYUN_DRIVE_APP_ID in the Amperfy target."
    case .invalidAudioItem:
      "The selected item is not an audio file."
    }
  }
}
