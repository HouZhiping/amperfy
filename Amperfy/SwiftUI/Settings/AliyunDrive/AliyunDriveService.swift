//
//  AliyunDriveService.swift
//  Amperfy
//

@preconcurrency import AliyunpanSDK
import Foundation

@MainActor
final class AliyunDriveService: AliyunDriveProviding {
  static let shared = AliyunDriveService()

  private static let scope = "user:base,file:all:read"
  private let client: AliyunpanClient?
  private var driveID: String?

  var isConfigured: Bool { client != nil }
  var isAuthorized: Bool { client?.accessToken != nil }

  private init(bundle: Bundle = .main) {
    let appID = (bundle.object(forInfoDictionaryKey: "AliyunDriveAppID") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let appID, !appID.isEmpty, !appID.contains("$(") {
      client = AliyunpanClient(appId: appID, scope: Self.scope)
    } else {
      client = nil
    }
  }

  func authorize() async throws {
    guard let client else { throw AliyunDriveError.missingAppID }
    _ = try await client.authorize(credentials: .pkce)
    _ = try await resolveDriveID(client: client)
  }

  func list(parentFileID: String) async throws -> [AliyunDriveItem] {
    guard let client else { throw AliyunDriveError.missingAppID }
    _ = try await client.authorize(credentials: .pkce)
    let driveID = try await resolveDriveID(client: client)
    var marker: String?
    var result: [AliyunDriveItem] = []

    repeat {
      let response = try await client.send(AliyunpanScope.File.GetFileList(.init(
        drive_id: driveID,
        parent_file_id: parentFileID,
        limit: 100,
        marker: marker,
        order_by: .name,
        order_direction: .asc,
        fields: "*"
      )))
      result.append(contentsOf: response.items.compactMap(Self.mapFile))
      marker = response.next_marker
    } while marker?.isEmpty == false

    return result
  }

  func streamURL(for item: AliyunDriveItem) async throws -> URL {
    guard item.kind == .audio else { throw AliyunDriveError.invalidAudioItem }
    guard let client else { throw AliyunDriveError.missingAppID }
    _ = try await client.authorize(credentials: .pkce)
    return try await client.send(AliyunpanScope.File.GetFileDownloadUrl(.init(
      drive_id: item.driveID,
      file_id: item.fileID,
      expire_sec: 14_400
    ))).url
  }

  func disconnect() {
    client?.cleanToken()
    driveID = nil
  }

  private func resolveDriveID(client: AliyunpanClient) async throws -> String {
    if let driveID { return driveID }
    let response = try await client.send(AliyunpanScope.User.GetDriveInfo())
    driveID = response.default_drive_id
    return response.default_drive_id
  }

  private static func mapFile(_ file: AliyunpanFile) -> AliyunDriveItem? {
    if file.isFolder {
      return AliyunDriveItem(
        driveID: file.drive_id,
        fileID: file.file_id,
        name: file.name,
        kind: .folder,
        contentType: nil,
        size: nil
      )
    }
    guard file.category == .audio else { return nil }
    return AliyunDriveItem(
      driveID: file.drive_id,
      fileID: file.file_id,
      name: file.name,
      kind: .audio,
      contentType: file.mime_type,
      size: file.size
    )
  }
}
