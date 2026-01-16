import Foundation
import Combine

struct PortProcess: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let processName: String
    let port: Int
    let protocol_: String
    let user: String
    var isActive: Bool = true

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(port)
    }

    static func == (lhs: PortProcess, rhs: PortProcess) -> Bool {
        lhs.pid == rhs.pid && lhs.port == rhs.port
    }
}

struct PinnedPort: Codable, Identifiable, Hashable {
    var id: Int { port }
    let port: Int
    let label: String?

    init(port: Int, label: String? = nil) {
        self.port = port
        self.label = label
    }
}

class PinnedPortsManager: ObservableObject {
    @Published var pinnedPorts: [PinnedPort] = []

    private let userDefaultsKey = "pinnedPorts"

    init() {
        load()
    }

    func isPinned(_ port: Int) -> Bool {
        pinnedPorts.contains { $0.port == port }
    }

    func pin(_ port: Int, label: String? = nil) {
        guard !isPinned(port) else { return }
        pinnedPorts.append(PinnedPort(port: port, label: label))
        pinnedPorts.sort { $0.port < $1.port }
        save()
    }

    func unpin(_ port: Int) {
        pinnedPorts.removeAll { $0.port == port }
        save()
    }

    func toggle(_ port: Int, label: String? = nil) {
        if isPinned(port) {
            unpin(port)
        } else {
            pin(port, label: label)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pinnedPorts) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PinnedPort].self, from: data) {
            pinnedPorts = decoded
        }
    }
}

class PortMonitor: ObservableObject {
    @Published var processes: [PortProcess] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pinnedPorts: [PinnedPort] = []

    let pinnedManager = PinnedPortsManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward pinnedManager changes to trigger view updates
        pinnedManager.$pinnedPorts
            .sink { [weak self] ports in
                self?.pinnedPorts = ports
            }
            .store(in: &cancellables)

        // Initialize with current value
        pinnedPorts = pinnedManager.pinnedPorts
    }

    func refresh() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.scanPorts() ?? []
            DispatchQueue.main.async {
                self?.processes = result
                self?.isLoading = false
            }
        }
    }

    private func scanPorts() -> [PortProcess] {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", "-P", "-n"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to run lsof: \(error.localizedDescription)"
            }
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return parseLsofOutput(output)
    }

    private func parseLsofOutput(_ output: String) -> [PortProcess] {
        var results: [PortProcess] = []
        var seen = Set<String>()

        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() { // Skip header
            // Only process LISTEN connections (servers listening on ports)
            guard line.contains("(LISTEN)") else { continue }

            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }

            let processName = String(components[0])
            guard let pid = Int32(components[1]) else { continue }
            let user = String(components[2])

            // The NAME field is at index 8 (format: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME)
            // For LISTEN lines, it looks like "*:3000" or "127.0.0.1:4000"
            let nameField = String(components[8])

            // Extract port from name field like "*:8080" or "127.0.0.1:3000"
            if let colonIndex = nameField.lastIndex(of: ":") {
                let portStr = String(nameField[nameField.index(after: colonIndex)...])

                if let port = Int(portStr) {
                    // Determine protocol
                    let proto = line.contains("TCP") ? "TCP" : (line.contains("UDP") ? "UDP" : "")

                    let key = "\(pid)-\(port)"
                    if !seen.contains(key) {
                        seen.insert(key)
                        results.append(PortProcess(
                            pid: pid,
                            processName: processName,
                            port: port,
                            protocol_: proto,
                            user: user
                        ))
                    }
                }
            }
        }

        return results.sorted { $0.port < $1.port }
    }

    func killProcess(_ process: PortProcess, force: Bool = false) -> Bool {
        let signal: Int32 = force ? SIGKILL : SIGTERM
        let result = kill(process.pid, signal)

        if result == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refresh()
            }
            return true
        }
        return false
    }

    func killProcessWithSudo(_ process: PortProcess) {
        let script = """
        do shell script "kill -9 \(process.pid)" with administrator privileges
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if error == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.refresh()
                }
            }
        }
    }
}
