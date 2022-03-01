//
//  ContentView.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/16/22.
//

import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
	@EnvironmentObject var cvm: CameraViewModel
	let viewWidth: CGFloat = UIScreen.main.bounds.width
	let viewHeight: CGFloat = UIScreen.main.bounds.height
	public var previewFrame: CGRect {
		let aspectRatio: CGFloat = 1080 / 1920
		return CGRect(x: 0, y: 0, width: viewWidth, height: viewWidth / aspectRatio)
	}
    var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			if self.cvm.didFinishTakingContent && self.cvm.showCapturedContentReview {
				CameraCaptureReviewView(viewWidth: self.viewWidth, viewHeight: viewHeight, previewFrame: self.previewFrame)
			} else {
				CameraCaptureView(previewFrame: self.previewFrame)
			}
		}
		.onAppear {
			self.cvm.checkForCameraPermissions()
		}
	}
}

struct CameraCaptureReviewView: View {
	@EnvironmentObject var cvm: CameraViewModel
	@State private var selectedImage: UIImage? = nil
	@State private var isTryingToSaveContent: Bool = false
	public let viewWidth: CGFloat
	public let viewHeight: CGFloat
	public let previewFrame: CGRect
	var body: some View {
		ZStack {
			VStack(spacing: 0) {
				ZStack {
					Color.gray.opacity(0.1)
						.frame(width: self.previewFrame.width, height: self.previewFrame.height)
						.cornerRadius(15)
					if let url = self.cvm.videoPlayerURL {
						let player: AVPlayer = AVPlayer(url: url)
						CustomVideoPlayer(player: player)
							.frame(width: self.previewFrame.width, height: self.previewFrame.height)
							.cornerRadius(15)
							.simultaneousGesture(TapGesture(count: 1).onEnded {
								player.play()
							})
							.onAppear {
								player.play()
							}
					} else if let capturedImage = self.cvm.capturedImage, !self.cvm.isMultiCaptureEnabled {
						Image(uiImage: capturedImage)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.cornerRadius(15)
					} else if let selectedImage = self.selectedImage, self.cvm.isMultiCaptureEnabled {
						Image(uiImage: selectedImage)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.cornerRadius(15)
					}
				}
				.overlay(
					VStack {
						HStack {
							Button {
								DispatchQueue.main.async {
									self.cvm.goBackToCameraFromReview()
									self.isTryingToSaveContent = false
									self.selectedImage = nil
								}
							} label: {
								Image(systemName: "xmark")
									.font(.system(size: 24).bold())
									.foregroundColor(Color.white)
									.padding(12)
									.shadow(color: Color.black.opacity(0.7), radius: 10, x: 0, y: 0)
							}
							
							Spacer()
						}
						Spacer()
						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: -30) {
								ForEach(self.cvm.multiCapturedImages, id: \.self) { image in
									Image(uiImage: image)
										.resizable()
										.scaledToFit()
										.overlay(RoundedRectangle(cornerRadius: 5).stroke(self.selectedImage == image ? Color.white : Color.clear, lineWidth: 1))
										.mask(RoundedRectangle(cornerRadius: 5))
										.overlay(
											VStack {
												HStack {
													Spacer()
													if let selectedImage = selectedImage, self.selectedImage == image && !self.cvm.multiCapturedImages.isEmpty {
														Button {
															DispatchQueue.main.async {
																self.cvm.multiCapturedImages.remove(at: self.cvm.multiCapturedImages.firstIndex(of: selectedImage)!)
																if self.cvm.multiCapturedImages.count == 0 {
																	self.cvm.goBackToCameraFromReview()
																	self.isTryingToSaveContent = false
																	self.selectedImage = nil
																} else {
																	self.selectedImage = self.cvm.multiCapturedImages.first
																}
															}
														} label: {
															RoundedRectangle(cornerRadius: 5)
																.fill(Color.white)
																.frame(width: 20, height: 20)
																.overlay(
																	Image(systemName: "xmark")
																		.font(.system(size: 10).bold())
																		.foregroundColor(Color.black)
																)
														}
													}
												}
												Spacer()
											}
										)
										.frame(width: 110, height: 110)
										.onTapGesture {
											DispatchQueue.main.async {
												self.selectedImage = image
											}
										}
										.onAppear {
											DispatchQueue.main.async {
												self.selectedImage = self.cvm.multiCapturedImages.first
											}
										}
								}
							}
						}
						.frame(width: self.previewFrame.width, height: 120)
					}
				)
				HStack {
					if self.isTryingToSaveContent {
						ProgressView()
							.progressViewStyle(CircularProgressViewStyle())
							.frame(width: 60, height: 60)
					} else if self.cvm.didFinishSavingContent {
						Image(systemName: "checkmark.square.fill")
							.font(.system(size: 24).bold())
							.foregroundColor(Color.white)
							.frame(width: 60, height: 60)
					} else {
						Button {
							DispatchQueue.main.async {
								var multiCaptureSaveCount: Int = 0
								self.isTryingToSaveContent = true
								if self.cvm.isMultiCaptureEnabled {
									for image in self.cvm.multiCapturedImages {
										self.cvm.savePhoto(image)
										multiCaptureSaveCount += 1
										if multiCaptureSaveCount == self.cvm.multiCapturedImages.count {
											self.isTryingToSaveContent = false
										}
									}
								} else {
									if let url = self.cvm.videoPlayerURL {
										self.cvm.saveMovieToCameraRoll(url: url, error: nil) { didSave in
											self.cvm.didFinishSavingContent = didSave
										}
									} else if let capturedImage = self.cvm.capturedImage {
										self.cvm.savePhoto(capturedImage)
									}
								}
							}
						} label: {
							Image(systemName: "square.and.arrow.down")
								.font(.system(size: 24).bold())
								.foregroundColor(Color.white)
								.frame(width: 60, height: 60)
						}
					}
					Spacer()
				}
				.animation(.spring(), value: self.isTryingToSaveContent)
				.onChange(of: self.cvm.didFinishSavingContent) { didSave in
					DispatchQueue.main.async {
						if didSave && !self.cvm.isMultiCaptureEnabled {
							self.isTryingToSaveContent = false
						}
					}
				}
				Spacer()
			}
		}
	}
}

struct CameraCaptureView: View {
	@EnvironmentObject var cvm: CameraViewModel
	@State var focusCirclePoint: CGPoint? = nil
	@State var canSwitchCamera: Bool = true
	@State private var isAnimatingFocusPoint: Bool = false
	public let previewFrame: CGRect
	var body: some View {
		ZStack {
			VStack {
				ZStack {
					if self.cvm.flashMode == .on && self.cvm.movieFileOutput.isRecording && self.cvm.currentDevicePosition == .front {
						Color.white
					} else {
						Color.black
					}
				}
				.frame(width: self.previewFrame.width, height: self.previewFrame.height)
				.cornerRadius(15)
				Spacer()
			}
			
			VStack(spacing: 0) {
				CameraView(focusCirclePoint: self.$focusCirclePoint, canSwitchCamera: self.$canSwitchCamera, frame: self.previewFrame)
					.frame(width: self.previewFrame.width, height: self.previewFrame.height)
					.shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 10)
					.opacity(self.cvm.flashMode == .on && self.cvm.movieFileOutput.isRecording && self.cvm.currentDevicePosition == .front ? 0.1 : 1.0)
					.overlay(
						ZStack {
							VStack {
								Spacer()
								RecordButton(isMultiCaptureEnabled: self.$cvm.isMultiCaptureEnabled)
									.frame(width: 100, height: 100, alignment: .center)
									.opacity(self.cvm.isCapturingPhoto ? 0.5 : 1.0)
									.overlay(
										ZStack {
											if self.cvm.recordTimerCount == 0.0 {
												Circle()
													.stroke(Color.white, lineWidth: self.cvm.isCapturingPhoto ? 0.5 : 3)
													.frame(width: 80, height: 80)
												Circle()
													.fill(self.cvm.isCapturingPhoto ? Color.white.opacity(0.01) : Color.clear)
													.frame(width: 100, height: 100)
											} else if self.cvm.recordTimerCount > 0.0 {
												Circle()
													.trim(from: 0.0, to: self.cvm.recordTimerCount/10.0)
													.stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
													.foregroundColor(Color.red)
													.rotationEffect(Angle(degrees: 270))
													.frame(width: 90, height: 90)
													.animation(.linear, value: self.cvm.recordTimerCount)
											}
										}
									)
							}
							.padding(.bottom, 26)
							
							if let focusPoint = self.focusCirclePoint {
								Circle()
									.stroke(Color.white, lineWidth: 2)
									.frame(width: isAnimatingFocusPoint ? 40 : 50, height: isAnimatingFocusPoint ? 40 : 50)
									.overlay(
										Circle()
											.fill(Color.white.opacity(0.2))
											.frame(width: isAnimatingFocusPoint ? 35 : 45, height: isAnimatingFocusPoint ? 35 : 45)
									)
									.position(x: focusPoint.x, y: focusPoint.y)
									.animation(.easeInOut, value: isAnimatingFocusPoint)
									.frame(width: self.previewFrame.width, height: self.previewFrame.height)
									.clipShape(RoundedRectangle(cornerRadius: 15))
									.onAppear {
										isAnimatingFocusPoint = true
										DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
											self.focusCirclePoint = nil
											self.isAnimatingFocusPoint = false
										}
									}
							}
						}
					)

				if !self.cvm.isCapturingVideo && !self.cvm.isCapturingPhoto && !self.cvm.didFinishTakingContent {
					HStack(alignment: .center, spacing: 24) {
						if self.cvm.multiCapturedImages.isEmpty {
							Button {
								self.cvm.isMultiCaptureEnabled.toggle()
							} label: {
								Image(systemName: self.cvm.isMultiCaptureEnabled ? "plus.square.fill.on.square.fill" : "plus.square.on.square")
									.font(.system(size: 24))
									.foregroundColor(Color.white)
									.frame(width: 50, height: 50)
							}
						} else {
							Button {
								self.cvm.multiCapturedImages.removeLast()
								if self.cvm.multiCapturedImages.isEmpty {
									self.cvm.isMultiCaptureEnabled = false
								}
							} label: {
								Image(systemName: "arrow.turn.up.left")
									.font(.system(size: 24))
									.foregroundColor(Color.white)
									.frame(width: 50, height: 50)
							}
							
						}
						
						Button {
							if self.cvm.flashMode == .off {
								self.cvm.flashMode = .on
							} else {
								self.cvm.flashMode = .off
							}
						} label: {
							Image(systemName: self.cvm.flashMode == .off ? "bolt.slash.fill" : "bolt.fill")
								.font(.system(size: 24))
								.foregroundColor(Color.white)
								.frame(width: 50, height: 50)
						}
						Button {
							if self.canSwitchCamera {
								self.cvm.rotateCamera()
								self.canSwitchCamera = false
								DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
									self.canSwitchCamera = true
								}
							}
						} label: {
							Image(systemName: "arrow.2.squarepath")
								.font(.system(size: 24))
								.foregroundColor(Color.white)
								.frame(width: 50, height: 50)
						}
					}
					.padding(.top, 12)
					.frame(width: self.previewFrame.width)
					.overlay(
						HStack(alignment: .center) {
							if self.cvm.isMultiCaptureEnabled && !self.cvm.multiCapturedImages.isEmpty {
								HStack(spacing: -45) {
									ForEach(self.cvm.multiCapturedImages, id: \.self) { image in
										Image(uiImage: image)
											.resizable()
											.scaledToFit()
											.mask(RoundedRectangle(cornerRadius: 5))
											.frame(width: 50, height: 50)
									}
									Spacer()
								}
								.frame(width: self.previewFrame.width/2.2)
								Spacer()
								Button {
									DispatchQueue.main.async {
										self.cvm.didFinishTakingContent = true
										self.cvm.showCapturedContentReview = true
										if self.cvm.multiCapturedImages.count == 1 {
											self.cvm.capturedImage = self.cvm.multiCapturedImages[0]
											self.cvm.isMultiCaptureEnabled = false
											self.cvm.multiCapturedImages = []
										}
									}
								} label: {
									Text("Done")
										.bold()
										.foregroundColor(Color.black)
										.frame(width: 60, height: 30)
										.background(Color.white)
										.cornerRadius(15)
								}
							}
						}
							.padding(.top, 12)
					)
					.animation(.spring(), value: self.cvm.multiCapturedImages)
				} else {
					HStack(alignment: .center, spacing: 24) {
						Image(systemName: "plus.square.on.square")
							.font(.system(size: 24))
							.foregroundColor(self.cvm.isMultiCaptureEnabled ? Color.green : Color.white)
							.frame(width: 50, height: 50)
						
						Image(systemName: self.cvm.flashMode == .off ? "bolt.slash.fill" : "bolt.fill")
							.font(.system(size: 24))
							.foregroundColor(Color.white)
							.frame(width: 50, height: 50)
						Image(systemName: "arrow.2.squarepath")
							.font(.system(size: 24))
							.foregroundColor(Color.white)
							.frame(width: 50, height: 50)
					}
					.padding(.top, 12)
					.frame(width: self.previewFrame.width)
					.opacity(0.1)
				}
				Spacer()
			}
		}
		.onDisappear {
			self.cvm.recordTimerCount = 0.0
			self.cvm.session.stopRunning()
		}
	}
}

public struct CameraView: UIViewRepresentable {
	@EnvironmentObject var cvm: CameraViewModel
	@Binding var focusCirclePoint: CGPoint?
	@Binding var canSwitchCamera: Bool
	public var frame: CGRect
	private let view: UIView = UIView()
	private let flashLayer: CALayer = CALayer()

	public func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}
	
	public func makeUIView(context: UIViewRepresentableContext<CameraView>) -> UIView {
		self.view.frame = self.frame
		let preview = AVCaptureVideoPreviewLayer(session: self.cvm.session)
		
		let dragPanGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.zoomDragGesture(_:)))
		dragPanGesture.delegate = context.coordinator
		self.view.addGestureRecognizer(dragPanGesture)
		
		let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.tapToFocusGesture(_:)))
		singleTapGesture.delegate = context.coordinator
		singleTapGesture.numberOfTapsRequired = 1
		self.view.addGestureRecognizer(singleTapGesture)
		
		let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.doubleTapGesture(_:)))
		doubleTapGesture.delegate = context.coordinator
		doubleTapGesture.numberOfTapsRequired = 2
		self.view.addGestureRecognizer(doubleTapGesture)
		
		singleTapGesture.require(toFail: doubleTapGesture)
		
		preview.frame = self.frame
		preview.videoGravity = self.cvm.videoGravity
		preview.cornerRadius = 15
		self.view.backgroundColor = .clear
		self.view.layer.addSublayer(preview)
		return self.view
	}
	
	public func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<CameraView>) {
		uiView.frame = self.frame

		if let focusPoint = self.cvm.tappedFocusPoint {
			self.focusView(focusPoint: focusPoint)
		}
	}
	
	public class Coordinator: NSObject, UIGestureRecognizerDelegate {
		public var parent: CameraView
		init(parent: CameraView) {
			self.parent = parent
		}
		
		@objc func tapToFocusGesture(_ sender: UITapGestureRecognizer) {
			let view = self.parent.view
			view.frame = self.parent.frame
			let tapLocation = sender.location(in: view)
			self.parent.focusCirclePoint = tapLocation
			self.parent.cvm.tapToFocus(tapLocation: tapLocation, viewSize: self.parent.frame)
		}
		
		@objc func zoomDragGesture(_ sender: UIPanGestureRecognizer) {
			self.parent.cvm.videoZoom(translHeight: sender.translation(in: self.parent.view).y)
		}
		
		@objc func doubleTapGesture(_ sender: UITapGestureRecognizer) {
			if self.parent.canSwitchCamera {
				self.parent.cvm.rotateCamera()
				self.parent.canSwitchCamera = false
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
					self.parent.canSwitchCamera = true
				}
			}
		}
		
		public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
			if gestureRecognizer is UITapGestureRecognizer {
				return false
			}
			return true
		}
	}
	
	private func focusView(focusPoint: CGPoint) {
		guard let focusImage = self.cvm.focusImage else {
			return
		}
		let image = UIImage(named: focusImage)
		let focusView = UIImageView(image: image)
		focusView.center = focusPoint
		focusView.alpha = 0.0
		self.view.addSubview(focusView)
		UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations: {
			focusView.alpha = 1.0
			focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
		}) { (success) in
			UIView.animate(withDuration: 0.15, delay: 0.5, options: .curveEaseInOut, animations: {
				focusView.alpha = 0.0
				focusView.transform = CGAffineTransform(translationX: 0.6, y: 0.6)
			}) { (success) in
				focusView.removeFromSuperview()
			}
		}
	}
}

struct RecordButton: UIViewRepresentable {
	@EnvironmentObject var cvm: CameraViewModel
	@State private var plusImageLayer: CALayer = CALayer()
	@Binding var isMultiCaptureEnabled: Bool
	private let view: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
	private let innerCircle: CAShapeLayer = CAShapeLayer()
	private let innerCircleFrame: CGRect = CGRect(x: 0, y: 0, width: 70, height: 70)
	private let plusImageView = UIImageView(image: UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 38))))
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}
	
	func makeUIView(context: UIViewRepresentableContext<RecordButton>) -> UIView {
		let tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.tapGesture(_:)))
		tapGesture.delegate = context.coordinator
		tapGesture.numberOfTapsRequired = 1
		self.view.addGestureRecognizer(tapGesture)
		let longPressGesture: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.longPress(_:)))
		longPressGesture.delegate = context.coordinator
		self.view.addGestureRecognizer(longPressGesture)
		let dragPanGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.zoomDragGesture(_:)))
		dragPanGesture.delegate = context.coordinator
		self.view.addGestureRecognizer(dragPanGesture)
		
		plusImageView.tintColor = .clear
		plusImageView.layer.position = CGPoint(x: self.view.frame.midX, y: self.view.frame.midY)
		DispatchQueue.main.async {
			self.plusImageLayer = plusImageView.layer
		}
		self.view.layer.addSublayer(self.plusImageLayer)
		
		innerCircle.backgroundColor = UIColor.white.cgColor
		innerCircle.opacity = 0.0
		innerCircle.frame = self.innerCircleFrame
		innerCircle.position = CGPoint(x: self.view.frame.midX, y: self.view.frame.midY)
		innerCircle.cornerRadius = self.innerCircleFrame.height/2
		self.view.layer.addSublayer(innerCircle)
		
		return self.view
	}
	
	func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<RecordButton>) {
		plusImageView.tintColor = self.isMultiCaptureEnabled ? .white : .clear
		plusImageView.layer.position = CGPoint(x: uiView.frame.midX, y: uiView.frame.midY)
		uiView.layer.replaceSublayer(self.plusImageLayer, with: plusImageView.layer)
		DispatchQueue.main.async {
			self.plusImageLayer = plusImageView.layer
		}
		
		innerCircle.backgroundColor = UIColor.white.cgColor
		innerCircle.opacity = 0.2
		innerCircle.frame = self.innerCircleFrame
		innerCircle.position = CGPoint(x: uiView.frame.midX, y: uiView.frame.midY)
		innerCircle.cornerRadius = self.innerCircleFrame.height/2
		uiView.layer.replaceSublayer(innerCircle, with: innerCircle)
	}
	
	class Coordinator: NSObject, UIGestureRecognizerDelegate {
		public var parent: RecordButton
		private lazy var recordTimer: Timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
			DispatchQueue.main.async {
				self.parent.cvm.recordTimerCount += 0.1
				if self.parent.cvm.recordTimerCount >= 9.9 {
					DispatchQueue.main.async {
						timer.invalidate()
						self.parent.cvm.endMovieRecording()
					}
				}
			}
		}
		
		init(parent: RecordButton) {
			self.parent = parent
		}
		
		@objc func zoomDragGesture(_ sender: UIPanGestureRecognizer) {
			let view: UIView = UIView()
			view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
			self.parent.cvm.videoZoom(translHeight: sender.translation(in: self.parent.view).y)
		}
		
		@objc func tapGesture(_ sender: UITapGestureRecognizer) {
			switch sender.state {
				case .cancelled, .failed, .began, .changed, .possible:
					break
				case .ended:
					if !self.parent.cvm.isCapturingVideo {
						DispatchQueue.main.async {
							self.parent.cvm.takePhoto()
						}
					}
				default:
					break
			}
		}
		
		@objc func longPress(_ sender: UILongPressGestureRecognizer) {
			switch sender.state {
				case .possible:
					break
				case .began:
					DispatchQueue.main.async {
						self.recordTimer.fire()
						self.parent.cvm.startMovieRecording()
					}
				case .cancelled, .ended, .failed:
					DispatchQueue.main.async {
						if self.parent.cvm.movieFileOutput.isRecording {
							self.recordTimer.invalidate()
							self.parent.cvm.endMovieRecording()
						} else {
							self.parent.cvm.endMovieRecording()
							self.recordTimer.invalidate()
							self.parent.cvm.recordTimerCount = 0.0
						}
					}
				default:
					break
			}
		}
		
		func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
			if gestureRecognizer is UILongPressGestureRecognizer {
				return false
			}
			return true
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	@State static var cvm = CameraViewModel()
    static var previews: some View {
        ContentView()
			.environmentObject(cvm)
    }
}
