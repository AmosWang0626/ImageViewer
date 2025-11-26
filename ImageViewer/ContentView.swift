//
//  ContentView.swift
//  ImageViewer
//
//  Created by Dorian Wang on 2025/11/25.
//

import SwiftUI
import AppKit
import Foundation

// MARK: - HistoryManager
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var history: [URL] = [] {
        didSet {
            saveHistory()
        }
    }
    
    private let historyKey = "FolderHistory"
    
    private init() {
        loadHistory()
    }
    
    func addFolder(_ url: URL) {
        // 移除已存在的相同URL
        history.removeAll { $0.absoluteString == url.absoluteString }
        // 将新URL插入到开头
        history.insert(url, at: 0)
        // 限制历史记录数量为20条
        if history.count > 20 {
            history.removeLast(history.count - 20)
        }
    }
    
    func removeFolder(at index: Int) {
        guard index < history.count else { return }
        history.remove(at: index)
    }
    
    func removeFolder(_ url: URL) {
        history.removeAll { $0.absoluteString == url.absoluteString }
    }
    
    func clearHistory() {
        history.removeAll()
    }

    private func saveHistory() {
        let urls = history.map { $0.absoluteString }
        UserDefaults.standard.set(urls, forKey: historyKey)
    }
    
    private func loadHistory() {
        guard let urls = UserDefaults.standard.array(forKey: historyKey) as? [String] else {
            history = []
            return
        }
        
        history = urls.compactMap { URL(string: $0) }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @State private var currentIndex = 0
    @State private var imageFiles: [URL] = []
    @State private var folderURL: URL?
    @State private var errorMessage: String?
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var needsAutoScaleAdjustment = false
    @State private var showingHistory = false
    @StateObject private var historyManager = HistoryManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("选择文件夹") {
                        selectFolder()
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !imageFiles.isEmpty {
                // 主要图片显示区域
                GeometryReader { geometry in
                    ZStack {
                        AsyncImage(url: imageFiles[currentIndex]) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .rotationEffect(.degrees(rotationAngle))
                                .scaleEffect(scale * rotationScaleFactor())
                                .offset(offset)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value.magnitude
                            needsAutoScaleAdjustment = false
                        }
                        .onEnded { value in
                            lastScale = scale
                            // 限制缩放范围
                            if lastScale < 0.5 {
                                lastScale = 0.5
                                scale = 0.5
                            } else if lastScale > 5.0 {
                                lastScale = 5.0
                                scale = 5.0
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onAppear {
                    // 注册键盘事件监听器
                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                        handleKeyDown(event)
                        return event
                    }
                    
                    // 注册通知中心监听器
                    NotificationCenter.default.addObserver(
                        forName: Notification.Name("LoadFolder"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let url = notification.userInfo?["folderURL"] as? URL {
                            folderURL = url
                            loadImagesFromFolder()
                        }
                    }
                    
                    // 注册错误显示监听器
                    NotificationCenter.default.addObserver(
                        forName: Notification.Name("ShowError"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let message = notification.userInfo?["message"] as? String {
                            errorMessage = message
                        }
                    }
                }
                
                // 底部状态栏
                HStack {
                    Text(imageFiles[currentIndex].lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("Image \(currentIndex + 1) of \(imageFiles.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                
                // 导航控件
                HStack {
                    // 左侧导航按钮
                    HStack {
                        Button(action: previousImage) {
                            Image(systemName: "arrow.left.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .keyboardShortcut(KeyEquivalent.leftArrow, modifiers: [])
                        .disabled(currentIndex == 0)
                    }
                    .padding(.leading, 10)
                    
                    Spacer()
                    
                    // 中间控制按钮组
                    HStack(spacing: 15) {
                        // 缩放控制按钮
                        HStack(spacing: 5) {
                            Button(action: {
                                scale = max(0.5, scale / 1.5)
                                lastScale = scale
                                needsAutoScaleAdjustment = false
                            }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(KeyEquivalent("-"), modifiers: [])
                            
                            Button(action: {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                needsAutoScaleAdjustment = true
                            }) {
                                Text("100%")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(KeyEquivalent("0"), modifiers: [.command])
                            
                            Button(action: {
                                scale = min(5.0, scale * 1.5)
                                lastScale = scale
                                needsAutoScaleAdjustment = false
                            }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(KeyEquivalent("="), modifiers: [])
                        }
                        
                        // 旋转控制按钮
                        HStack(spacing: 5) {
                            Button(action: {
                                rotationAngle -= 90
                            }) {
                                Image(systemName: "rotate.left")
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(KeyEquivalent("["), modifiers: [])
                            
                            Button(action: {
                                rotationAngle = 0
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                needsAutoScaleAdjustment = true
                            }) {
                                Text("重置")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(KeyEquivalent("r"), modifiers: [])
                            
                            Button(action: {
                                rotationAngle += 90
                            }) {
                                Image(systemName: "rotate.right")
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(KeyEquivalent("]"), modifiers: [])
                        }
                    }
                    
                    Spacer()
                    
                    // 右侧按钮
                    HStack {
                        Button(action: {
                            showingHistory = true
                        }) {
                            Image(systemName: "clock")
                        }
                        .buttonStyle(.borderless)
                        .keyboardShortcut("h", modifiers: [.command])
                        
                        Button("更换文件夹") {
                            selectFolder()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: nextImage) {
                            Image(systemName: "arrow.right.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .keyboardShortcut(KeyEquivalent.rightArrow, modifiers: [])
                        .disabled(currentIndex == imageFiles.count - 1)
                    }
                    .padding(.trailing, 10)
                }
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Text("未加载图片")
                        .font(.headline)
                        .padding()
                    
                    Button("选择文件夹") {
                        selectFolder()
                    }
                    .padding()
                    
                    if !historyManager.history.isEmpty {
                        Menu("最近的文件夹") {
                            ForEach(0..<min(5, historyManager.history.count), id: \.self) { index in
                                let url = historyManager.history[index]
                                Button(url.lastPathComponent) {
                                    loadFolderFromHistory(url)
                                }
                            }
                            
                            Divider()
                            
                            Button("查看全部历史记录") {
                                showingHistory = true
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // 注册通知中心监听器
                    NotificationCenter.default.addObserver(
                        forName: Notification.Name("LoadFolder"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let url = notification.userInfo?["folderURL"] as? URL {
                            folderURL = url
                            loadImagesFromFolder()
                        }
                    }
                    
                    // 注册错误显示监听器
                    NotificationCenter.default.addObserver(
                        forName: Notification.Name("ShowError"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let message = notification.userInfo?["message"] as? String {
                            errorMessage = message
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onChange(of: currentIndex) { _ in
            // 当切换图片时重置旋转角度和缩放
            resetImageTransform()
        }
        .onChange(of: rotationAngle) { _ in
            // 当旋转角度改变时，可能需要调整缩放
            if needsAutoScaleAdjustment {
                adjustScaleForRotation()
            }
        }
        .onDisappear {
            // 移除通知中心监听器
            NotificationCenter.default.removeObserver(self)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(showingHistory: $showingHistory)
        }
    }
    
    func loadFolderFromHistory(_ url: URL) {
        // 从历史记录加载文件夹
        guard FileManager.default.fileExists(atPath: url.path) else {
            // 如果文件夹不存在，从历史记录中移除
            historyManager.removeFolder(url)
            
            // 通过通知传递错误信息
            NotificationCenter.default.post(
                name: Notification.Name("ShowError"),
                object: nil,
                userInfo: ["message": "文件夹不存在: \(url.path)"]
            )
            return
        }
        
        // 检查是否有权限访问该文件夹
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isReadableKey])
            guard resourceValues.isReadable == true else {
                // 通过通知传递错误信息
                NotificationCenter.default.post(
                    name: Notification.Name("ShowError"),
                    object: nil,
                    userInfo: ["message": "权限被拒绝: \(url.path)\n\n解决方法:\n1. 右键点击应用程序并选择\"打开\"\n2. 前往系统偏好设置 > 安全性与隐私 > 隐私\n3. 确保此应用程序有权访问该文件夹\n\n或者, 使用\"选择文件夹\"按钮重新选择文件夹。"]
                )
                return
            }
        } catch {
            // 通过通知传递错误信息
            NotificationCenter.default.post(
                name: Notification.Name("ShowError"),
                object: nil,
                userInfo: ["message": "检查文件夹权限时出错: \(error.localizedDescription)"]
            )
            return
        }
        
        folderURL = url
        loadImagesFromFolder()
    }
    
    func rotationScaleFactor() -> CGFloat {
        // 根据旋转角度计算额外的缩放因子
        let normalizedAngle = abs(rotationAngle.truncatingRemainder(dividingBy: 360))
        
        // 当旋转到90度或270度时，返回适当的缩放因子以确保完整显示
        if normalizedAngle == 90 || normalizedAngle == 270 {
            return 0.8
        }
        
        return 1.0
    }
    
    func adjustScaleForRotation() {
        // 根据旋转角度自动调整缩放
        let normalizedAngle = abs(rotationAngle.truncatingRemainder(dividingBy: 360))
        
        if normalizedAngle == 90 || normalizedAngle == 270 {
            // 旋转90或270度时，自动调整缩放以适应视图
            if scale == 1.0 {
                scale = 0.8
                lastScale = 0.8
            }
        } else if normalizedAngle == 0 || normalizedAngle == 180 {
            // 旋转到0或180度时，恢复正常缩放
            if scale == 0.8 {
                scale = 1.0
                lastScale = 1.0
            }
        }
    }
    
    func handleKeyDown(_ event: NSEvent) {
        // 处理键盘事件
        switch event.keyCode {
        case 126: // 上箭头键
            rotationAngle -= 90
        case 125: // 下箭头键
            rotationAngle += 90
        default:
            break
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择文件夹"
        
        if panel.runModal() == .OK {
            folderURL = panel.url
            if let url = folderURL {
                historyManager.addFolder(url)
            }
            loadImagesFromFolder()
        }
    }
    
    func loadImagesFromFolder() {
        guard let folderURL = folderURL else { return }
        
        let supportedExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        imageFiles = []
        currentIndex = 0
        errorMessage = nil
        resetImageTransform()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            imageFiles = fileURLs.filter { url in
                let ext = url.pathExtension.lowercased()
                return supportedExtensions.contains(ext)
            }.sorted { url1, url2 in
                url1.lastPathComponent < url2.lastPathComponent
            }
            
            if imageFiles.isEmpty {
                errorMessage = "在所选文件夹中未找到图片。\n支持的格式: JPG, PNG, GIF, BMP, TIFF, WEBP"
            }
        } catch let error as NSError where error.code == NSFileReadNoPermissionError {
            errorMessage = "权限被拒绝: \(folderURL.path)\n\n解决方法:\n1. 右键点击应用程序并选择\"打开\"\n2. 前往系统偏好设置 > 安全性与隐私 > 隐私\n3. 确保此应用程序有权访问该文件夹\n\n或者, 使用\"选择文件夹\"按钮重新选择文件夹。"
        } catch {
            errorMessage = "加载文件夹内容时出错: \(error.localizedDescription)"
        }
    }
    
    func previousImage() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    func nextImage() {
        if currentIndex < imageFiles.count - 1 {
            currentIndex += 1
        }
    }
    
    func resetImageTransform() {
        rotationAngle = 0
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        needsAutoScaleAdjustment = true
    }
}

// MARK: - HistoryView
struct HistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var historyManager = HistoryManager.shared
    @Binding var showingHistory: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(historyManager.history.enumerated()), id: \.1) { index, url in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .font(.headline)
                            Text(url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            historyManager.removeFolder(at: index)
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        loadFolder(url)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("文件夹历史记录")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Button("关闭") {
                            showingHistory = false
                        }
                        .padding(.trailing, 10)
                        
                        Button("清除全部") {
                            historyManager.clearHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
            }

        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    func loadFolder(_ url: URL) {
        // 加载选中的文件夹
        guard FileManager.default.fileExists(atPath: url.path) else {
            // 如果文件夹不存在，从历史记录中移除
            if let index = historyManager.history.firstIndex(of: url) {
                historyManager.removeFolder(at: index)
            }
            
            // 通过通知传递错误信息
            NotificationCenter.default.post(
                name: Notification.Name("ShowError"), 
                object: nil, 
                userInfo: ["message": "文件夹不存在: \(url.path)"]
            )
            
            showingHistory = false
            return
        }
        
        // 检查是否有权限访问该文件夹
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isReadableKey])
            guard resourceValues.isReadable == true else {
                showingHistory = false
                
                // 通过通知传递错误信息
                NotificationCenter.default.post(
                    name: Notification.Name("ShowError"),
                    object: nil,
                    userInfo: ["message": "权限被拒绝: \(url.path)\n\n解决方法:\n1. 右键点击应用程序并选择\"打开\"\n2. 前往系统偏好设置 > 安全性与隐私 > 隐私\n3. 确保此应用程序有权访问该文件夹\n\n或者, 使用\"选择文件夹\"按钮重新选择文件夹。"]
                )
                return
            }
        } catch {
            showingHistory = false
            
            // 通过通知传递错误信息
            NotificationCenter.default.post(
                name: Notification.Name("ShowError"),
                object: nil,
                userInfo: ["message": "检查文件夹权限时出错: \(error.localizedDescription)"]
            )
            return
        }
        
        // 关闭历史记录视图
        showingHistory = false
        
        // 通知主视图加载文件夹
        NotificationCenter.default.post(name: Notification.Name("LoadFolder"), object: nil, userInfo: ["folderURL": url])
    }
    
    func deleteItems(offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            historyManager.removeFolder(at: index)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}