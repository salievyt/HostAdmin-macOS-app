//
//  UI.swift
//  Hosting Curator
//
//  Created by M1 on 29/11/25.
//

import SwiftUI
import Combine

// MARK: - Models
struct Server: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var status: ServerStatus
    var ip: String?
    var cpuUsage: Double? // 0...1
    var memoryUsage: Double? // 0...1
    var uptime: TimeInterval?

    enum ServerStatus: String, Codable {
        case online = "Online"
        case offline = "Offline"
        case maintenance = "Maintenance"
    }
}

// MARK: - ViewModel
@MainActor
class ServerViewModel: ObservableObject {
    @Published var servers: [Server] = []
    @Published var selectedServer: Server?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Replace with your real endpoint
    private let apiURLString = "https://your-api.com/servers"

    func loadServers() async {
        isLoading = true
        errorMessage = nil

        // Try real network call first; if it fails, fall back to mock data
        if let url = URL(string: apiURLString) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    let decoded = try JSONDecoder().decode([Server].self, from: data)
                    servers = decoded
                    if selectedServer == nil { selectedServer = servers.first }
                    isLoading = false
                    return
                } else {
                    // non-200: fallthrough to mock
                    print("Non-200 response: \(response)")
                }
            } catch {
                print("Network load failed: \(error)")
            }
        }

        // Fallback mock data (so the UI shows something right away)
        await Task.sleep(200_000_000) // 0.2s small delay for feel
        servers = Self.mockServers()
        selectedServer = servers.first
        isLoading = false
    }

    func refresh() {
        Task { await loadServers() }
    }

    func performAction(_ action: ServerAction, on server: Server) {
        // Placeholder: integrate real action calls (SSH, API) here.
        switch action {
        case .restart:
            print("Request restart for \(server.name)")
            // Simulate change
            if let idx = servers.firstIndex(of: server) {
                servers[idx].status = .maintenance
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    servers[idx].status = .online
                }
            }
        case .powerOff:
            print("Request power off for \(server.name)")
            if let idx = servers.firstIndex(of: server) {
                servers[idx].status = .offline
            }
        case .ssh:
            print("Open SSH to \(server.ip ?? "-")")
        }
    }

    enum ServerAction {
        case restart, powerOff, ssh
    }

    static func mockServers() -> [Server] {
        return [
            Server(id: "srv-1", name: "web-01", status: .online, ip: "192.168.1.10", cpuUsage: 0.28, memoryUsage: 0.54, uptime: 86_400 * 6),
            Server(id: "srv-2", name: "db-01", status: .online, ip: "192.168.1.11", cpuUsage: 0.62, memoryUsage: 0.71, uptime: 86_400 * 20),
            Server(id: "srv-3", name: "cache-01", status: .maintenance, ip: "192.168.1.12", cpuUsage: 0.10, memoryUsage: 0.22, uptime: 86_400 * 1),
            Server(id: "srv-4", name: "backup-01", status: .offline, ip: "192.168.1.20", cpuUsage: 0.0, memoryUsage: 0.0, uptime: 0)
        ]
    }
}

// MARK: - UI Views
struct HostingCuratorAppView: View {
    @StateObject private var vm = ServerViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(vm: vm)
        } detail: {
            DashboardView(vm: vm)
        }
        .navigationSplitViewStyle(.balanced)
        .task { await vm.loadServers() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { vm.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh server statuses")
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var vm: ServerViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Hosting Curator")
                .font(.title2)
                .bold()
                .padding(.vertical, 8)

            List(selection: $vm.selectedServer) {
                Section("Servers") {
                    ForEach(vm.servers) { server in
                        HStack(spacing: 10) {
                            statusCircle(for: server)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .font(.headline)
                                Text(server.ip ?? "—")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(server)
                    }
                }
            }
            .listStyle(.sidebar)

            Spacer()

            HStack {
                Button(action: { vm.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    func statusCircle(for server: Server) -> some View {
        switch server.status {
        case .online: Circle().foregroundStyle(.green)
        case .offline: Circle().foregroundStyle(.red)
        case .maintenance: Circle().foregroundStyle(.orange)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var vm: ServerViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Dashboard")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                if vm.isLoading { ProgressView().scaleEffect(0.8) }
            }
            .padding([.top, .horizontal])

            if let server = vm.selectedServer {
                ServerDetailView(server: server, vm: vm)
                    .padding()
            } else {
                Text("Select a server from the sidebar to see details.")
                    .foregroundColor(.secondary)
                    .padding()
            }

            // Grid of small cards
            ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(vm.servers) { server in
                    ServerCardView(server: server)
                        .onTapGesture { vm.selectedServer = server }
                }
            }
            .padding()
            }

            Spacer()
        }
    }
}

struct ServerCardView: View {
    let server: Server

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(server.name)
                    .font(.headline)
                Spacer()
                Text(server.status.rawValue)
                    .font(.caption)
                    .padding(6)
                    .background(statusBackground(server.status))
                    .cornerRadius(6)
            }

            if let cpu = server.cpuUsage {
                ProgressView(value: cpu) {
                    Text("CPU")
                }
            }

            if let mem = server.memoryUsage {
                ProgressView(value: mem) {
                    Text("Memory")
                }
            }

            HStack {
                Text(server.ip ?? "—")
                    .font(.caption)
                Spacer()
                if let uptime = server.uptime {
                    Text(formatUptime(uptime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.06)))
    }

    func statusBackground(_ status: Server.ServerStatus) -> Color {
        switch status {
        case .online: return Color.green.opacity(0.15)
        case .offline: return Color.red.opacity(0.12)
        case .maintenance: return Color.orange.opacity(0.12)
        }
    }

    func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        if days > 0 { return "\(days)d" }
        let hrs = (Int(seconds) % 86400) / 3600
        return "\(hrs)h"
    }
}

struct ServerDetailView: View {
    let server: Server
    @ObservedObject var vm: ServerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.title2)
                        .bold()
                    Text(server.ip ?? "—")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                Spacer()
                StatusBadge(status: server.status)
            }

            HStack(spacing: 12) {
                Button(action: { vm.performAction(.restart, on: server) }) {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                Button(action: { vm.performAction(.powerOff, on: server) }) {
                    Label("Power Off", systemImage: "power")
                }
                Button(action: { vm.performAction(.ssh, on: server) }) {
                    Label("SSH", systemImage: "terminal")
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("CPU")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: server.cpuUsage ?? 0)
                        .frame(width: 200)
                }

                VStack(alignment: .leading) {
                    Text("Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: server.memoryUsage ?? 0)
                        .frame(width: 200)
                }

                Spacer()
            }

            Divider()

            Text("Logs")
                .font(.headline)

            ScrollView {
                Text(fakeLogs(for: server))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
            }
            .frame(maxHeight: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func fakeLogs(for server: Server) -> String {
        return "[\(Date())] \(server.name): sample log line 1\n[\(Date())] \(server.name): sample log line 2\n[\(Date())] \(server.name): sample log line 3"
    }
}

struct StatusBadge: View {
    let status: Server.ServerStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(8)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(8)
    }

    var badgeColor: Color {
        switch status {
        case .online: return .green
        case .offline: return .red
        case .maintenance: return .orange
        }
    }
}

// MARK: - App Entry
@main
struct HostingCuratorApp: App {
    var body: some Scene {
        WindowGroup("Hosting Curator") {
            HostingCuratorAppView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

// MARK: - Previews
struct HostingCuratorApp_Previews: PreviewProvider {
    static var previews: some View {
        HostingCuratorAppView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
