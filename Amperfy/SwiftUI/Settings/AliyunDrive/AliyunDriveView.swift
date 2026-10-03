//
//  AliyunDriveView.swift
//  Amperfy
//

import AmperfyKit
import SwiftUI

@MainActor
final class AliyunDriveViewModel: ObservableObject {
  @Published private(set) var items: [AliyunDriveItem] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isAuthorized: Bool
  @Published private(set) var playingItemID: String?
  @Published var errorMessage: String?

  let parentFileID: String
  let service: AliyunDriveProviding
  private var appDelegate: AppDelegate {
    UIApplication.shared.delegate as! AppDelegate
  }

  init(parentFileID: String, service: AliyunDriveProviding = AliyunDriveService.shared) {
    self.parentFileID = parentFileID
    self.service = service
    self.isAuthorized = service.isAuthorized
  }

  func load() async {
    guard service.isConfigured else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      items = try await service.list(parentFileID: parentFileID)
      isAuthorized = service.isAuthorized
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func play(_ item: AliyunDriveItem) async {
    guard let accountInfo = appDelegate.storage.settings.accounts.active else {
      errorMessage = "Select an Amperfy account before playing cloud music."
      return
    }
    playingItemID = item.id
    defer { playingItemID = nil }
    do {
      let url = try await service.streamURL(for: item)
      let account = appDelegate.storage.main.library.getAccount(info: accountInfo)
      let playable = appDelegate.storage.main.library.upsertExternalStream(
        account: account,
        id: "aliyundrive:\(item.driveID):\(item.fileID)",
        title: item.name,
        url: url,
        contentType: item.contentType
      )
      appDelegate.player.play(context: PlayContext(name: "Aliyun Drive", playables: [playable]))
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func disconnect() {
    service.disconnect()
    items = []
    isAuthorized = false
  }
}

struct AliyunDriveView: View {
  @StateObject private var model: AliyunDriveViewModel
  private let title: String

  init(
    parentFileID: String = "root",
    title: String = "Aliyun Drive",
    service: AliyunDriveProviding = AliyunDriveService.shared
  ) {
    self.title = title
    _model = StateObject(wrappedValue: AliyunDriveViewModel(
      parentFileID: parentFileID,
      service: service
    ))
  }

  var body: some View {
    Group {
      if !model.service.isConfigured {
        ContentUnavailableView(
          "Aliyun Drive App ID Required",
          systemImage: "externaldrive.badge.exclamationmark",
          description: Text(
            "Create an app in the Aliyun Drive Open Platform, then set " +
              "ALIYUN_DRIVE_APP_ID in the Amperfy target build settings."
          )
        )
      } else if !model.isAuthorized && !model.isLoading {
        VStack(spacing: 16) {
          ContentUnavailableView(
            "Connect Aliyun Drive",
            systemImage: "externaldrive.badge.plus",
            description: Text("Authorize Amperfy to browse and play your cloud music.")
          )
          Button("Connect") {
            Task { await model.load() }
          }
          .buttonStyle(.borderedProminent)
        }
      } else if model.isLoading && model.items.isEmpty {
        ProgressView("Loading Aliyun Drive…")
      } else {
        fileList
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
    .refreshable { await model.load() }
    .alert("Aliyun Drive", isPresented: Binding(
      get: { model.errorMessage != nil },
      set: { if !$0 { model.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "Unknown error")
    }
    .toolbar {
      if model.isAuthorized {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Disconnect", role: .destructive) { model.disconnect() }
        }
      }
    }
  }

  private var fileList: some View {
    List(model.items) { item in
      if item.isFolder {
        NavigationLink {
          AliyunDriveView(
            parentFileID: item.fileID,
            title: item.name,
            service: model.service
          )
        } label: {
          Label(item.name, systemImage: "folder")
        }
      } else {
        Button {
          Task { await model.play(item) }
        } label: {
          HStack {
            Label(item.name, systemImage: "music.note")
            Spacer()
            if model.playingItemID == item.id {
              ProgressView()
            } else if let size = item.size {
              Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .foregroundStyle(.secondary)
            }
          }
        }
        .disabled(model.playingItemID != nil)
      }
    }
    .overlay {
      if !model.isLoading && model.items.isEmpty {
        ContentUnavailableView(
          "No Music Here",
          systemImage: "music.note.list",
          description: Text("Open another folder or add audio files to Aliyun Drive.")
        )
      }
    }
  }
}

