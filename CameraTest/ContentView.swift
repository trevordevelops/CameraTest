//
//  ContentView.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/16/22.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
	@EnvironmentObject var cvm: CameraViewModel
//	@State var didFinishTakingContent: Bool = false
	let viewWidth: CGFloat = UIScreen.main.bounds.width
	let viewHeight: CGFloat = UIScreen.main.bounds.height
	public var previewFrame: CGRect {
		let aspectRatio: CGFloat = 1080 / 1920
		return CGRect(x: 0, y: 0, width: viewWidth, height: viewWidth / aspectRatio)
	}
    var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			if self.cvm.didFinishTakingContent {
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
	@State private var selectedImage: UIImage = UIImage()
	public let viewWidth: CGFloat
	public let viewHeight: CGFloat
	public let previewFrame: CGRect
	var body: some View {
		ZStack {
			VStack(spacing: 0) {
				Image(uiImage: self.cvm.isMultiCaptureEnabled && !self.cvm.multiCapturedImages.isEmpty ? self.selectedImage : self.cvm.capturedImage)
					.resizable()
					.scaledToFit()
					.cornerRadius(15)
					.overlay(
						VStack {
							HStack {
								Button {
									self.cvm.checkForCameraPermissions()
									self.cvm.didFinishTakingContent = false
									self.cvm.isMultiCaptureEnabled = false
									self.cvm.multiCapturedImages = []
									self.cvm.capturedImage = UIImage()
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
					Button {
						self.cvm.savePhoto(self.cvm.capturedImage)
					} label: {
						Image(systemName: "square.and.arrow.down")
							.font(.system(size: 24).bold())
							.foregroundColor(Color.white)
							.padding(12)
					}
					Spacer()
				}
				Spacer()
			}
		}
	}
}

struct CameraCaptureView: View {
	@EnvironmentObject var cvm: CameraViewModel
	@State private var timerCount: CGFloat = 0.0
	@State private var focusPoint: CGPoint = .zero
	@State private var showFocusPoint: Bool = false
	@State private var isAnimatingFocusPoint: Bool = false
	public let previewFrame: CGRect
	var body: some View {
		ZStack {
			VStack(spacing: 0) {
				CameraView(frame: self.previewFrame)
					.frame(width: self.previewFrame.width, height: self.previewFrame.height)
					.shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 10)
					.overlay(
						RoundedRectangle(cornerRadius: 15)
							.fill(self.cvm.frontFlash)
							.opacity(0.8)
					)
					.simultaneousGesture(TapGesture(count: 2).onEnded {
						self.cvm.rotateCamera()
					})
					.overlay(
						VStack {
							Spacer()
							if !self.cvm.isCapturingPhotos {
								Button {
									DispatchQueue.main.async {
//										if !self.cvm.didFinishTakingContent && !self.cvm.movieFileOutput.isRecording {
//											self.cvm.isCapturing = true
//											self.cvm.takePhoto()
//										}
										if !self.cvm.movieFileOutput.isRecording {
											if !self.cvm.isMultiCaptureEnabled {
												self.timer().fire()
												self.cvm.startMovieRecording()
											}
										} else {
											self.cvm.endMovieRecording()
											self.timerCount = 0.0
											self.timer().invalidate()
										}
										
									}
								} label: {
									Circle()
										.fill(Color.white.opacity(0.2))
										.frame(width: 70, height: 70)
										.overlay(
											ZStack {
												if self.timerCount == 0.0 {
													Circle()
														.stroke(Color.white, lineWidth: 2)
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
//								.onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity, pressing: { isPressing in
//									DispatchQueue.main.async {
//										if isPressing {
//											if !self.cvm.isMultiCaptureEnabled {
//												self.timer().fire()
//												self.cvm.toggleMovieRecording()
//											}
//										} else {
//											self.cvm.endMovieRecording()
//											self.timerCount = 0.0
//											self.timer().invalidate()
//										}
//									}
//								}, perform: {
//									print("AB")
//								})
							}
						}
							.padding(.bottom, 26)
					)
//					.simultaneousGesture(
//						DragGesture(minimumDistance: 2, coordinateSpace: .global)
//							.onChanged(self.cvm.videoZoom(value:))
//					)
					
//					.simultaneousGesture(
//						DragGesture(minimumDistance: 0, coordinateSpace: .local).onEnded { drag in
//							self.cvm.tapToFocus(tapLocation: drag.location, viewSize: CGSize(width: self.previewFrame.width, height: self.previewFrame.height))
//							DispatchQueue.main.async {
//								self.showFocusPoint = true
//								self.focusPoint = drag.location
//							}
//						}
//					)

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
						self.cvm.rotateCamera()
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
			
			if self.showFocusPoint {
				Circle()
					.stroke(Color.white, lineWidth: 2)
					.frame(width: isAnimatingFocusPoint ? 40 : 50, height: isAnimatingFocusPoint ? 40 : 50)
					.overlay(
						Circle()
							.fill(Color.white.opacity(0.2))
							.frame(width: isAnimatingFocusPoint ? 35 : 45, height: isAnimatingFocusPoint ? 35 : 45)
					)
					.position(x: self.focusPoint.x, y: self.focusPoint.y)
					.animation(.easeInOut, value: isAnimatingFocusPoint)
					.onAppear {
						isAnimatingFocusPoint = true
						DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
							self.showFocusPoint = false
							self.isAnimatingFocusPoint = false
						}
					}
			}
		}
		.onDisappear {
			self.cvm.session.stopRunning()
		}
	}
	
	private func timer() -> Timer {
		return Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
			self.timerCount += 0.1
			if self.timerCount == 10.0 {
				self.cvm.endMovieRecording()
				timer.invalidate()
			}
		}
	}
}


public struct CameraView: UIViewRepresentable {
	@EnvironmentObject var cvm: CameraViewModel
	public var frame: CGRect
	
	public func makeUIView(context: Context) -> UIView {
		let view = UIView(frame: self.frame)
		let preview = AVCaptureVideoPreviewLayer(session: self.cvm.session)
		preview.frame = view.frame
		preview.videoGravity = self.cvm.videoGravity
		preview.cornerRadius = 15
		view.backgroundColor = .black
		view.layer.addSublayer(preview)
		return view
	}
	
	public func updateUIView(_ uiView: UIViewType, context: Context) {
		let view = UIView(frame: UIScreen.main.bounds)
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
}

struct ContentView_Previews: PreviewProvider {
	@State static var cvm = CameraViewModel()
    static var previews: some View {
        ContentView()
			.environmentObject(cvm)
    }
}
