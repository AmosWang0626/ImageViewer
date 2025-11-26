//
//  ContentView.swift
//  ImageViewer
//
//  Created by Dorian Wang on 2025/11/25.
//

import SwiftUI
import AppKit

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
                    
                    Button("Select Folder") {
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
                                Text("Reset")
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
                        Button("Change Folder") {
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
                    
                    Text("No images loaded")
                        .font(.headline)
                        .padding()
                    
                    Button("Select Folder") {
                        selectFolder()
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK {
            folderURL = panel.url
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
                errorMessage = "No images found in the selected folder.\nSupported formats: JPG, PNG, GIF, BMP, TIFF, WEBP"
            }
        } catch {
            errorMessage = "Error loading folder contents:\n$error.localizedDescription"
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}