//
//  ContentView.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/16/22.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
	@EnvironmentObject var ue: UserEvents
	@State private var count: Double = 0.0
	@State private var didFinishTakingVideo: Bool = false
	@State var point: CGPoint = .zero
	@State var showPoint: Bool = false
	@State var isAnimating: Bool = false
    var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			CameraView()
				.simultaneousGesture(
					DragGesture(minimumDistance: 4, coordinateSpace: .local)
						.onChanged(self.ue.videoZoom(value:))
				)
				.simultaneousGesture(TapGesture(count: 2).onEnded {
					self.ue.rotateCamera()
				})
				.gesture(
					DragGesture(minimumDistance: 0, coordinateSpace: .local).onEnded { drag in
						self.ue.tapToFocus(tapLocation: drag.location, viewSize: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
						DispatchQueue.main.async {
							self.showPoint = true
							self.point = drag.location
						}
						
					})
			if self.showPoint {
				Circle()
					.stroke(Color.white, lineWidth: 2)
					.frame(width: isAnimating ? 40 : 50, height: isAnimating ? 40 : 50)
					.position(x: point.x, y: point.y)
					.animation(.easeInOut, value: isAnimating)
					.onAppear {
						isAnimating = true
					}
			}
			HStack {
				Spacer()
				VStack {
					Button {
						if self.ue.flashMode == .off {
							self.ue.flashMode = .on
						} else {
							self.ue.flashMode = .off
						}
					} label: {
						Image(systemName: self.ue.flashMode == .off ? "bolt.slash.fill" : "bolt.fill")
							.font(.system(size: 24))
							.foregroundColor(Color.white)
					}
				}
			}
			VStack {
				Spacer()
				if !didFinishTakingVideo {
					Button {
						if self.ue.movieFileOutput.isRecording {
							self.ue.toggleMovieRecording()
							didFinishTakingVideo = true
						} else if !self.didFinishTakingVideo {
							self.ue.takePhoto()
						}
					} label: {
						Circle()
							.fill(Color.white.opacity(0.2))
							.frame(width: 70, height: 70, alignment: .bottom)
							.overlay(
								Circle()
									.stroke(Color.white, lineWidth: 2)
									.frame(width: 80, height: 80)
							)
					}
					.simultaneousGesture(
						LongPressGesture(minimumDuration: 1.0, maximumDistance: .infinity)
							.onEnded({ _ in
								Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
									count += 1.0
									if count == 10.0 {
										didFinishTakingVideo = true
										self.ue.toggleMovieRecording()
										timer.invalidate()
									}
								})
								self.ue.toggleMovieRecording()
							})
					)
				}
			}
		}
		.onAppear {
			self.ue.checkForCameraPermissions()
		}
		.onDisappear {
			self.ue.session.stopRunning()
			/*
			 reset focus point
			 */
		}
    }
}

public struct CameraView: UIViewRepresentable {
	@EnvironmentObject var ue: UserEvents
	public func makeUIView(context: Context) -> UIView {
		let view = UIView(frame: UIScreen.main.bounds)
		self.ue.cameraPreview = AVCaptureVideoPreviewLayer(session: ue.session)
		self.ue.cameraPreview.frame = view.frame
		self.ue.cameraPreview.videoGravity = ue.videoGravity
		self.ue.session.startRunning()
		view.layer.addSublayer(self.ue.cameraPreview)
		return view
	}
	
	public func updateUIView(_ uiView: UIViewType, context: Context) {
		let view = UIView(frame: UIScreen.main.bounds)
		if let focusPoint = self.ue.tappedFocusPoint {
			guard let focusImage = self.ue.focusImage else {
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
    static var previews: some View {
        ContentView()
    }
}
