import SwiftUI

struct PortsView: View {
    @ObservedObject var portMonitor: PortMonitor
    @State private var searchText = ""
    @State private var showingKillAlert = false
    @State private var processToKill: PortProcess?

    var filteredProcesses: [PortProcess] {
        let procs = portMonitor.processes
        if searchText.isEmpty {
            return procs
        }
        return procs.filter {
            $0.processName.localizedCaseInsensitiveContains(searchText) ||
            String($0.port).contains(searchText) ||
            String($0.pid).contains(searchText)
        }
    }

    var pinnedProcesses: [PortProcess] {
        let pinned = Set(portMonitor.pinnedPorts.map { $0.port })
        return filteredProcesses.filter { pinned.contains($0.port) }
    }

    var unpinnedProcesses: [PortProcess] {
        let pinned = Set(portMonitor.pinnedPorts.map { $0.port })
        return filteredProcesses.filter { !pinned.contains($0.port) }
    }

    // Pinned ports that have no active process
    var inactivePinnedPorts: [PinnedPort] {
        let activePorts = Set(portMonitor.processes.map { $0.port })
        return portMonitor.pinnedPorts.filter { !activePorts.contains($0.port) }
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.blue.opacity(0.1),
                    Color.cyan.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.title2)
                            .foregroundStyle(.linearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Text("Ports Monitor")
                            .font(.headline)
                    }
                    Spacer()

                    HStack(spacing: 12) {
                        GlassButton(icon: "arrow.clockwise", action: { portMonitor.refresh() })
                            .disabled(portMonitor.isLoading)

                        GlassButton(icon: "xmark", action: { NSApp.terminate(nil) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search port, process, or PID...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // Content
                if portMonitor.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Scanning ports...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                } else if let error = portMonitor.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange.gradient)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                } else if filteredProcesses.isEmpty && inactivePinnedPorts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text(searchText.isEmpty ? "No listening ports" : "No matches")
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            // Pinned Section
                            if !pinnedProcesses.isEmpty || !inactivePinnedPorts.isEmpty {
                                SectionHeader(title: "Pinned", icon: "pin.fill")

                                // Active pinned processes
                                ForEach(pinnedProcesses) { process in
                                    ProcessRow(
                                        process: process,
                                        isPinned: true,
                                        onPin: { portMonitor.pinnedManager.toggle(process.port, label: process.processName) },
                                        onKill: {
                                            processToKill = process
                                            showingKillAlert = true
                                        }
                                    )
                                }

                                // Inactive pinned ports
                                ForEach(inactivePinnedPorts) { pinnedPort in
                                    InactivePinnedRow(
                                        pinnedPort: pinnedPort,
                                        onUnpin: { portMonitor.pinnedManager.unpin(pinnedPort.port) }
                                    )
                                }
                            }

                            // Other Ports Section
                            if !unpinnedProcesses.isEmpty {
                                if !pinnedProcesses.isEmpty || !inactivePinnedPorts.isEmpty {
                                    SectionHeader(title: "Other Ports", icon: "network")
                                        .padding(.top, 8)
                                }

                                ForEach(unpinnedProcesses) { process in
                                    ProcessRow(
                                        process: process,
                                        isPinned: false,
                                        onPin: { portMonitor.pinnedManager.toggle(process.port, label: process.processName) },
                                        onKill: {
                                            processToKill = process
                                            showingKillAlert = true
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }

                // Footer with legend
                VStack(spacing: 6) {
                    // Port color legend
                    HStack(spacing: 12) {
                        LegendItem(color: .green, label: "HTTP")
                        LegendItem(color: .orange, label: "3xxx")
                        LegendItem(color: .pink, label: "4xxx")
                        LegendItem(color: .purple, label: "5xxx")
                        LegendItem(color: .blue, label: "8xxx")
                    }
                    .font(.system(size: 9))

                    HStack {
                        Text("\(filteredProcesses.count) port\(filteredProcesses.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
        .frame(width: 380, height: 520)
        .alert("Kill Process", isPresented: $showingKillAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Kill", role: .destructive) {
                if let process = processToKill {
                    if !portMonitor.killProcess(process) {
                        portMonitor.killProcessWithSudo(process)
                    }
                }
            }
            Button("Force Kill (SIGKILL)", role: .destructive) {
                if let process = processToKill {
                    if !portMonitor.killProcess(process, force: true) {
                        portMonitor.killProcessWithSudo(process)
                    }
                }
            }
        } message: {
            if let process = processToKill {
                Text("Kill \(process.processName) (PID: \(process.pid)) on port \(String(process.port))?")
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.gradient)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

struct GlassButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovering ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(isHovering ? 0.3 : 0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct InactivePinnedRow: View {
    let pinnedPort: PinnedPort
    let onUnpin: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Port badge
            Text(String(pinnedPort.port))
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.6))
                .frame(minWidth: 54)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(pinnedPort.label ?? "Unknown")
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("Inactive")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            // Unpin button
            Button(action: onUnpin) {
                Image(systemName: "pin.slash.fill")
                    .font(.caption)
                    .foregroundColor(isHovering ? .orange : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 1)
                )
        )
        .opacity(0.7)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct ProcessRow: View {
    let process: PortProcess
    let isPinned: Bool
    let onPin: () -> Void
    let onKill: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Port badge - using String() to avoid comma formatting
            Text(String(process.port))
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(minWidth: 54)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: portGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: portGradient[0].opacity(0.4), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(process.processName)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // PID
                    HStack(spacing: 3) {
                        Text("PID")
                            .font(.system(size: 8, weight: .semibold))
                        Text(String(process.pid))
                    }
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.12), in: Capsule())

                    // Protocol
                    if !process.protocol_.isEmpty {
                        Text(process.protocol_)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.12), in: Capsule())
                    }

                    // User
                    Text(process.user)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            // Pin button
            Button(action: onPin) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundColor(isPinned ? .orange : (isHovering ? .orange.opacity(0.7) : .secondary.opacity(0.4)))
            }
            .buttonStyle(.plain)

            // Kill button
            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        isHovering
                            ? AnyShapeStyle(.red.gradient)
                            : AnyShapeStyle(.secondary.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(isHovering ? 0.2 : 0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isHovering ? 0.1 : 0.05), radius: isHovering ? 8 : 4, y: 2)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    var portGradient: [Color] {
        switch process.port {
        case 80, 443:
            return [.green, .mint]  // HTTP/HTTPS
        case 3000...3999:
            return [.orange, .yellow]  // Common dev servers (React, Node, Rails)
        case 4000...4999:
            return [.pink, .red]  // Phoenix, some dev tools
        case 5000...5999:
            return [.purple, .indigo]  // Flask, ASP.NET, development
        case 8000...8999:
            return [.blue, .cyan]  // Django, Spring, common alt HTTP
        default:
            return [.gray, .gray.opacity(0.7)]
        }
    }
}
