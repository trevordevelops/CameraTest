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
									self.cvm.checkForCameraPermissions()
									self.cvm.didFinishTakingContent = false
									self.cvm.isMultiCaptureEnabled = false
									self.cvm.multiCapturedImages = []
									self.cvm.capturedImage = nil
									self.cvm.videoPlayerURL = nil
									self.cvm.didFinishSavingContent = false
									self.isTryingToSaveContent = false
									self.cvm.showCapturedContentReview = false
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
										.overlay(RoundedRectangle(cornerRadius: 8).stroke(self.selectedImage == image ? Color.white : Color.clear, lineWidth: 1))
										.mask(RoundedRectangle(cornerRadius: 8))
										.frame(width: 90, height: 90)
										.onTapGesture {
											self.selectedImage = image
										}
										.onAppear {
											self.selectedImage = self.cvm.multiCapturedImages.first ?? UIImage()
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
							self.isTryingToSaveContent = true
							if let url = self.cvm.videoPlayerURL {
								self.cvm.saveMovieToCameraRoll(url: url, error: nil) { didSave in
									DispatchQueue.main.async {
										self.cvm.didFinishSavingContent = didSave
									}
								}
							} else if let capturedImage = self.cvm.capturedImage {
								self.cvm.savePhoto(capturedImage)
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
					if didSave {
						self.isTryingToSaveContent = false
					}
				}
				Spacer()
			}
		}
	}
}

struct CameraCaptureView: View {
	@EnvironmentObject var cvm: CameraViewModel
	@State var timerCount: CGFloat = 0.0
	@State var isPressing: Bool = false
	@State var focusCirclePoint: CGPoint? = nil
	@State var canSwitchCamera: Bool = true
	@State private var isAnimatingFocusPoint: Bool = false
	public let previewFrame: CGRect
	var body: some View {
		ZStack {
			VStack(spacing: 0) {
				CameraView(focusCirclePoint: self.$focusCirclePoint, canSwitchCamera: self.$canSwitchCamera, frame: self.previewFrame)
					.frame(width: self.previewFrame.width, height: self.previewFrame.height)
					.shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 10)
					.overlay(
						RoundedRectangle(cornerRadius: 15)
							.fill(self.cvm.frontFlash)
							.opacity(0.8)
					)
					.overlay(
						ZStack {
							VStack {
								Spacer()
								if !self.cvm.isCapturingPhotos {
									RecordButton(timerCount: self.$timerCount, isPressing: self.$isPressing)
										.frame(width: 100, height: 100, alignment: .center)
										.overlay(
											ZStack {
												if self.timerCount == 0.0 {
													Circle()
														.stroke(Color.white, lineWidth: self.isPressing ? 0.5 : 3)
														.frame(width: 80, height: 80)
													Image(systemName: "plus")
														.font(.system(size: 36))
														.foregroundColor(self.cvm.isMultiCaptureEnabled ? Color.white : Color.clear)
												} else {
													Circle()
														.trim(from: 0.0, to: self.timerCount/10.0)
														.stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
														.foregroundColor(Color.red)
														.rotationEffect(Angle(degrees: 270))
														.frame(width: 90, height: 90)
														.animation(.linear, value: self.timerCount)
												}
											}
										)
								}
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

				HStack(alignment: .center, spacing: 24) {
					if self.cvm.multiCapturedImages.isEmpty {
						Button {
							self.cvm.isMultiCaptureEnabled.toggle()
						} label: {
							Image(systemName: "plus.square.on.square")
								.font(.system(size: 24))
								.foregroundColor(self.cvm.isMultiCaptureEnabled ? Color.green : Color.white)
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
								self.cvm.didFinishTakingContent = true
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
				Spacer()
			}
		}
		.onDisappear {
			self.timerCount = 0.0
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
	
	public func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}
	
	public func makeUIView(context: UIViewRepresentableContext<CameraView>) -> UIView {
		let view = self.view
		view.frame = self.frame
		let preview = AVCaptureVideoPreviewLayer(session: self.cvm.session)
		
		
		let dragPanGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.zoomDragGesture(_:)))
		dragPanGesture.delegate = context.coordinator
		view.addGestureRecognizer(dragPanGesture)
		
		let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.tapToFocusGesture(_:)))
		singleTapGesture.delegate = context.coordinator
		singleTapGesture.numberOfTapsRequired = 1
		view.addGestureRecognizer(singleTapGesture)
		
		let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.doubleTapGesture(_:)))
		doubleTapGesture.delegate = context.coordinator
		doubleTapGesture.numberOfTapsRequired = 2
		view.addGestureRecognizer(doubleTapGesture)
		
		singleTapGesture.require(toFail: doubleTapGesture)
		
		preview.frame = view.frame
		preview.videoGravity = self.cvm.videoGravity
		preview.cornerRadius = 15
		view.backgroundColor = .black
		view.layer.addSublayer(preview)
		return view
	}
	
	public func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<CameraView>) {
		let view = UIView(frame: self.frame)
		if let focusPoint = self.cvm.tappedFocusPoint {
			guard let focusImage = self.cvm.focusImage else {
				return
			}
			let image = UIImage(named: focusImage)
			let focusView = UIImageView(image: image)
			focusView.center = focusPoint
			focusView.alpha = 0.0
			view.addSubview(focusView)
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
}

struct RecordButton: UIViewRepresentable {
	@EnvironmentObject var cvm: CameraViewModel
	@Binding var timerCount: CGFloat
	@Binding var isPressing: Bool
	
	private let view: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
	private let innerCircle: CAShapeLayer = CAShapeLayer()
	private let innerCircleFrame: CGRect = CGRect(x: 0, y: 0, width: 70, height: 70)
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}
	
	func makeUIView(context: UIViewRepresentableContext<RecordButton>) -> UIView {
		let tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.tapGesture(_:)))
		tapGesture.delegate = context.coordinator
		let longPressGesture: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.longPress(_:)))
		longPressGesture.delegate = context.coordinator
		let dragPanGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.zoomDragGesture(_:)))
		dragPanGesture.delegate = context.coordinator
		view.gestureRecognizers = [tapGesture, longPressGesture, dragPanGesture]
		return view
	}
	
	func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<RecordButton>) {
		if self.timerCount == 0.0 {
			innerCircle.backgroundColor = UIColor.white.cgColor
			innerCircle.opacity = 0.2
			innerCircle.frame = self.innerCircleFrame
			innerCircle.position = CGPoint(x: view.frame.midX, y: view.frame.midY)
			innerCircle.cornerRadius = self.innerCircleFrame.height/2
			view.layer.addSublayer(innerCircle)
		}
	}
	
	private func recordTimer() -> Timer {
		return Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
			DispatchQueue.main.async {
				self.timerCount += 0.1
				if self.timerCount == 10.0 {
					timer.invalidate()
					self.cvm.endMovieRecording()
				}
			}
		}
	}
	
	class Coordinator: NSObject, UIGestureRecognizerDelegate {
		public var parent: RecordButton
		init(parent: RecordButton) {
			self.parent = parent
		}
		
		@objc func zoomDragGesture(_ sender: UIPanGestureRecognizer) {
			let view: UIView = UIView()
			view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
			self.parent.cvm.videoZoom(translHeight: sender.translation(in: self.parent.view).y)
		}
		
		@objc func tapGesture(_ sender: UITapGestureRecognizer) {
			sender.numberOfTapsRequired = 1
			sender.numberOfTouchesRequired = 1
			self.parent.isPressing.toggle()
			self.parent.cvm.takePhoto()
		}
		
		@objc func longPress(_ sender: UILongPressGestureRecognizer) {
			switch sender.state {
				case .began:
					self.parent.cvm.startMovieRecording()
					self.parent.recordTimer().fire()
				case .cancelled, .ended, .failed:
					self.parent.cvm.endMovieRecording()
					self.parent.recordTimer().invalidate()
				default:
					break
			}
		}
		
		func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
