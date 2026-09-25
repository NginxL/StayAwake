import AppKit
import AwakeCore
import CryptoKit
import Foundation
import Security

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
        let size: Int
    }
    let tag_name: String
    let assets: [Asset]
}

struct AvailableUpdate {
    let version: AppVersion
    let archive: URL
    let checksum: URL
}

private struct UpdateError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var statusText = "从 GitHub Releases 获取正式版本"
    @Published private(set) var available: AvailableUpdate?
    @Published private(set) var isBusy = false

    private let repository = "NginxL/StayAwake"

    func check() {
        guard !isBusy else { return }
        isBusy = true
        available = nil
        statusText = "正在检查最新版本…"
        Task {
            defer { isBusy = false }
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
                request.timeoutInterval = 20
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("StayAwake", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 404 {
                    statusText = "还没有已发布的安装包。"
                    return
                }
                try requireSuccess(response)
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard let latest = AppVersion(release.tag_name),
                      let current = AppVersion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") else {
                    throw UpdateError(message: "版本信息无法识别，请查看 GitHub 发布页面。")
                }
                guard latest > current else {
                    statusText = "已是最新版本 v\(current)"
                    return
                }
                let name = "StayAwake-\(latest)-universal.zip"
                guard let archive = release.assets.first(where: { $0.name == name }),
                      let checksum = release.assets.first(where: { $0.name == name + ".sha256" }),
                      archive.size > 0, archive.size <= 100_000_000,
                      checksum.size > 0, checksum.size <= 4096,
                      validAssetURL(archive.browser_download_url, tag: release.tag_name),
                      validAssetURL(checksum.browser_download_url, tag: release.tag_name) else {
                    throw UpdateError(message: "最新版本缺少通用安装包或校验文件。")
                }
                available = AvailableUpdate(version: latest, archive: archive.browser_download_url,
                                            checksum: checksum.browser_download_url)
                statusText = "发现新版本 v\(latest)"
            } catch {
                statusText = "检查失败：\(error.localizedDescription)"
            }
        }
    }

    func install() {
        guard !isBusy, let update = available else { return }
        isBusy = true
        statusText = "正在下载并校验…"
        Task {
            var workspace: URL?
            var staged: URL?
            do {
                let destination = Bundle.main.bundleURL.standardizedFileURL
                let allowedParents = [URL(fileURLWithPath: "/Applications"),
                                      FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
                guard destination.lastPathComponent == "StayAwake.app",
                      allowedParents.contains(destination.deletingLastPathComponent()),
                      FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
                    throw UpdateError(message: "请先将醒着放入有写入权限的「应用程序」文件夹，再安装更新。")
                }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("StayAwake-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
                workspace = folder
                let (download, response) = try await URLSession.shared.download(from: update.archive)
                try requireSuccess(response)
                let archive = folder.appendingPathComponent("update.zip")
                try FileManager.default.moveItem(at: download, to: archive)
                let archiveData = try Data(contentsOf: archive, options: .mappedIfSafe)
                guard archiveData.count <= 100_000_000 else { throw UpdateError(message: "安装包大小异常。") }
                let (checksumData, checksumResponse) = try await URLSession.shared.data(from: update.checksum)
                try requireSuccess(checksumResponse)
                let expected = String(decoding: checksumData, as: UTF8.self).split(whereSeparator: \.isWhitespace).first.map(String.init)
                let actual = SHA256.hash(data: archiveData).map { String(format: "%02x", $0) }.joined()
                guard expected?.lowercased() == actual else { throw UpdateError(message: "SHA-256 校验失败，未安装更新。") }

                statusText = "正在准备安装…"
                let extracted = folder.appendingPathComponent("extracted")
                try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
                let entries = try await run("/usr/bin/unzip", ["-Z1", archive.path])
                guard entries.split(separator: "\n").allSatisfy({
                    !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..")
                }) else { throw UpdateError(message: "安装包包含无效路径，未安装更新。") }
                _ = try await run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path])
                let candidate = extracted.appendingPathComponent("StayAwake.app")
                let info = candidate.appendingPathComponent("Contents/Info.plist")
                let metadata = try PropertyListSerialization.propertyList(from: Data(contentsOf: info), format: nil) as? [String: Any]
                guard metadata?["CFBundleIdentifier"] as? String == "io.github.nginxl.StayAwake",
                      metadata?["CFBundleShortVersionString"] as? String == update.version.description,
                      FileManager.default.isExecutableFile(atPath: candidate.appendingPathComponent("Contents/MacOS/StayAwake").path) else {
                    throw UpdateError(message: "安装包身份或版本不匹配，未安装更新。")
                }
                var staticCode: SecStaticCode?
                guard SecStaticCodeCreateWithPath(candidate as CFURL, [], &staticCode) == errSecSuccess,
                      let staticCode,
                      SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
                    throw UpdateError(message: "安装包签名完整性检查失败。")
                }

                let pending = destination.deletingLastPathComponent()
                    .appendingPathComponent(".StayAwake-pending-\(UUID().uuidString).app")
                staged = pending
                try FileManager.default.copyItem(at: candidate, to: pending)
                // Helper waits for this process to exit, then swaps directories on the same volume.
                guard let helper = Bundle.main.url(forResource: "install-update", withExtension: "sh") else {
                    throw UpdateError(message: "应用缺少更新工具，请从 GitHub 下载完整版本。")
                }
                let helperCopy = folder.appendingPathComponent("install-update.sh")
                try FileManager.default.copyItem(at: helper, to: helperCopy)
                let installer = Process()
                installer.executableURL = URL(fileURLWithPath: "/bin/bash")
                installer.arguments = [helperCopy.path, String(ProcessInfo.processInfo.processIdentifier),
                                       pending.path, destination.path, folder.path]
                let logURL = folder.appendingPathComponent("install.log")
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
                let log = try FileHandle(forWritingTo: logURL)
                installer.standardOutput = log
                installer.standardError = log
                try installer.run()
                try? log.close()
                statusText = "即将重新打开醒着…"
                NSApplication.shared.terminate(nil)
            } catch {
                if let staged { try? FileManager.default.removeItem(at: staged) }
                if let workspace { try? FileManager.default.removeItem(at: workspace) }
                statusText = "更新失败：\(error.localizedDescription)"
                isBusy = false
            }
        }
    }

    private func validAssetURL(_ url: URL, tag: String) -> Bool {
        url.scheme == "https" && url.host == "github.com"
            && url.path.hasPrefix("/\(repository)/releases/download/\(tag)/")
    }

    private func requireSuccess(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw UpdateError(message: "无法从 GitHub 获取文件，请稍后重试。")
        }
    }

    private func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw UpdateError(message: "无法解压或检查安装包。") }
            return String(decoding: data, as: UTF8.self)
        }.value
    }
}
