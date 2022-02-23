//
//  UserEvents.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/16/22.
//

import SwiftUI
import AVFoundation
import Photos

class CameraViewModel: NSObject, ObservableObject {
	@Published var applicationName: String = ""
	@Published var preferredStartingCameraType: AVCaptureDevice.DeviceType = .builtInDualCamera
	@Published var preferredStartingCameraPosition: AVCaptureDevice.Position = .back
	@Published var videoQuality: AVCaptureSession.Preset = .hd1920x1080
	@Published var flashMode: AVCaptureDevice.FlashMode = .off
	@Published var focusImage: String?
	@Published var videoGravity: AVLayerVideoGravity = .resizeAspect
	@Published var tappedFocusPoint: CGPoint? = nil
	@Published  var session = AVCaptureSession()
	@Published var photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
	@Published var didFinishTakingContent: Bool = false
	@Published var movieFileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	private var backgroundRecordingID: UIBackgroundTaskIdentifier?
	private var videoDeviceInput: AVCaptureDeviceInput!
	private var audioDeviceInput: AVCaptureDeviceInput!
	private var setupResult: SessionSetupResult = .success
	private let sessionQueue = DispatchQueue(label: "session queue")
	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}
	@Published var capturedImage: UIImage = UIImage()
	@Published var multiCapturedImages: [UIImage] = []
	
	@Published var frontFlash: Color = Color.clear
	
	@Published var capturedMovieURLs: [URL] = []
	@Published var capturedAudioURLs: [URL] = []
	
	private var mutableCompTracks: [AVMutableCompositionTrack] = []
	private var insertTime = CMTime.zero
	
	@Published var isMultiCaptureEnabled: Bool = false
	@Published var isCapturingPhotos: Bool = false
	@Published var isCapturingVideo: Bool = false
	@Published var zoomAmount: CGFloat = 1
	private var zoomDragValueHeight: CGFloat = 0
	
	@Published var currentDevicePosition: AVCaptureDevice.Position = .back
	private var preferredRotatedCameraType: AVCaptureDevice.DeviceType = .builtInTrueDepthCamera
	private var preferredRotatedCameraPosition: AVCaptureDevice.Position = .front
	
	public func checkForCameraPermissions() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
			case .authorized:
				// The user has previously granted access to the camera.
//				session.startRunning()
				break
			case .notDetermined:
				sessionQueue.suspend()
				AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
					if !granted {
						self.setupResult = .notAuthorized
					}
					self.sessionQueue.resume()
				})
			default:
				setupResult = .notAuthorized
		}
		sessionQueue.async {
			self.configureSession()
		}
	}
	
	private func configureSession() {
		if setupResult != .success {
			return
		}
		self.removeSessionInOutPuts()
		self.session.beginConfiguration()
		self.session.sessionPreset = self.videoQuality
		do {
			var defaultVideoDevice: AVCaptureDevice?
			if self.currentDevicePosition == .front {
				if let preferredRotatedCamera = AVCaptureDevice.default(self.preferredRotatedCameraType, for: .video, position: self.preferredRotatedCameraPosition) {
					defaultVideoDevice = preferredRotatedCamera
				} else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
					defaultVideoDevice = frontCameraDevice
				}
			} else {
				if let preferredCameraDevice = AVCaptureDevice.default(self.preferredStartingCameraType, for: .video, position: self.preferredStartingCameraPosition) {
					defaultVideoDevice = preferredCameraDevice
				} else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
					defaultVideoDevice = backCameraDevice
				}
			}
			
			guard let videoDevice = defaultVideoDevice else {
				print("Default video device is unavailable.")
				setupResult = .configurationFailed
				self.session.commitConfiguration()
				return
			}
			self.videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
			if self.session.canAddInput(self.videoDeviceInput) {
				self.session.addInput(self.videoDeviceInput)
			} else {
				print("Couldn't add video device input to the self.ue.session.")
				setupResult = .configurationFailed
				self.session.commitConfiguration()
				return
			}
		} catch {
			print("Couldn't create video device input: \(error)")
			setupResult = .configurationFailed
			self.session.commitConfiguration()
			return
		}
		self.addAudioDevice()
		self.addPhotoOutput()
		self.addMovieOutput()
		self.session.commitConfiguration()
		self.session.startRunning()
	}
	
	private func removeSessionInOutPuts() {
		for input in self.session.inputs {
			self.session.removeInput(input)
		}
		for output in self.session.outputs {
			self.session.removeOutput(output)
		}
	}
	
	private func addAudioDevice() {
		do {
			guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
				setupResult = .configurationFailed
				self.session.commitConfiguration()
				return
			}
			self.audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
			if self.session.canAddInput(self.audioDeviceInput) {
				self.session.addInput(self.audioDeviceInput)
			} else {
				print("Could not add audio device input to the session")
			}
		} catch {
			print("Could not create audio device input: \(error)")
			setupResult = .configurationFailed
			self.session.commitConfiguration()
			return
		}
	}
	
	private func addPhotoOutput() {
		if self.session.canAddOutput(self.photoOutput) {
			self.session.addOutput(self.photoOutput)
		} else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			self.session.commitConfiguration()
			return
		}
	}
	
	private func addMovieOutput() {
		if self.session.canAddOutput(self.movieFileOutput) {
			self.session.addOutput(self.movieFileOutput)
			if let connection = self.movieFileOutput.connection(with: .video) {
				if connection.isVideoStabilizationSupported {
					connection.preferredVideoStabilizationMode = .auto
				}
			}
		}
	}
	
	public func rotateCamera() {
		DispatchQueue.main.async {
			let currentVideoDevice = self.videoDeviceInput.device
			let deviceCurrentPosition = currentVideoDevice.position
			switch deviceCurrentPosition {
				case .unspecified, .front:
					self.currentDevicePosition = .back
				case .back:
					self.currentDevicePosition = .front
				@unknown default:
					print("Unknown capture position. Defaulting to back, dual-camera.")
					self.currentDevicePosition = .back
			}
			if self.movieFileOutput.isRecording {
				self.movieFileOutput.stopRecording()
				self.session.stopRunning()
				self.configureSession()
				self.startMovieRecording()
			} else {
				self.configureSession()
			}
		}
	}
	
	public func videoZoom(value: DragGesture.Value) {
		do {
			let captureDevice = self.videoDeviceInput.device
			try captureDevice.lockForConfiguration()
			let maxZoomFactor: CGFloat = captureDevice.activeFormat.videoMaxZoomFactor
			DispatchQueue.main.async {
				let value = -value.translation.height
				var rawZoomFactor: CGFloat = 0
				if !self.movieFileOutput.isRecording {
					self.zoomDragValueHeight = value
					rawZoomFactor = (self.zoomDragValueHeight/UIScreen.main.bounds.height) * maxZoomFactor
				} else if self.zoomDragValueHeight != 0 && self.movieFileOutput.isRecording {
					rawZoomFactor = ((self.zoomDragValueHeight+value)/UIScreen.main.bounds.height) * maxZoomFactor
				} else {
					rawZoomFactor = (value/UIScreen.main.bounds.height) * maxZoomFactor
				}
				
				let zoomFactor = min(max(rawZoomFactor, 1), maxZoomFactor)
				captureDevice.videoZoomFactor = zoomFactor
				if captureDevice.videoZoomFactor == 1 {
					self.zoomDragValueHeight = 0
				}
			}
		} catch {
			print("Error locking configuration for camera zoom, drag gesture")
		}
	}
	
	public func tapToFocus(tapLocation: CGPoint, viewSize: CGSize) {
		let x = tapLocation.y / viewSize.height
		let y = 1.0 - tapLocation.x / viewSize.width
		let focusPoint = CGPoint(x: x, y: y)
		do {
			let device = self.videoDeviceInput.device
			try device.lockForConfiguration()
			if device.isFocusPointOfInterestSupported == true {
				device.focusPointOfInterest = focusPoint
				device.focusMode = .continuousAutoFocus
			}
			device.exposurePointOfInterest = focusPoint
			device.exposureMode = .autoExpose
			device.unlockForConfiguration()
			DispatchQueue.main.async {
				self.tappedFocusPoint = focusPoint
			}
		} catch {
			print(error)
		}
	}
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
	public func takePhoto() {
		self.sessionQueue.async {
			let photoSettings = AVCapturePhotoSettings()
			if self.videoDeviceInput.device.isFlashAvailable {
				photoSettings.flashMode = self.flashMode
			}
			self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
		}
	}
	
	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		if let error = error {
			print(error)
		} else if self.isMultiCaptureEnabled {
			self.isCapturingPhotos = false
		}
	}
	
	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		guard error == nil else { print("Error capturing photo: \(error!)"); return }

		if let photoData = photo.fileDataRepresentation() {
			let dataProvider = CGDataProvider(data: photoData as CFData)
			let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!,
									 decode: nil,
									 shouldInterpolate: true,
									 intent: CGColorRenderingIntent.defaultIntent)

			// TODO: implement imageOrientation
			// Set proper orientation for photo
			// If camera is currently set to front camera, flip image
			//          let imageOrientation = getImageOrientation()

			// For now, it is only right
			//2 options to save
			//First is to use UIImageWriteToSavedPhotosAlbum
//			savePhoto(image)
			//Second is adapting Apple documentation with data of the modified image
			//savePhoto(image.jpegData(compressionQuality: 1)!)
			DispatchQueue.main.async {
				let image = UIImage(cgImage: cgImageRef!, scale: 1, orientation: .right)
				if self.isMultiCaptureEnabled {
					self.multiCapturedImages.append(image)
					if self.multiCapturedImages.count == 10 {
						self.didFinishTakingContent = true
					}
				} else {
					self.capturedImage = image
					self.didFinishTakingContent = true
					self.isCapturingPhotos = false
					self.videoDeviceInput.device.videoZoomFactor = 1
				}
			}
		}
	}
	
	public func savePhoto(_ image: UIImage) {
		UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingWithError(_:didFinishSavingWithError:contextInfo:)), nil)
	}
	
	@objc private func didFinishSavingWithError(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
		//		DispatchQueue.main.async {
		//			self.ue.delegate?.didFinishSavingWithError(image, error: error, contextInfo: contextInfo)
		//		}
	}
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
	public func startMovieRecording() {
		self.sessionQueue.async {
			do {
				try self.videoDeviceInput.device.lockForConfiguration()
				if self.videoDeviceInput.device.isTorchModeSupported(self.videoDeviceInput.device.torchMode) && self.flashMode == .on {
					self.videoDeviceInput.device.torchMode = .on
					self.videoDeviceInput.device.unlockForConfiguration()
				}
				let movieFileOutputConnection = self.movieFileOutput.connection(with: .video)
				if self.currentDevicePosition == .front {
					movieFileOutputConnection?.isVideoMirrored = true
				}
				movieFileOutputConnection?.videoOrientation = .portrait
				let availableVideoCodecTypes = self.movieFileOutput.availableVideoCodecTypes
				if availableVideoCodecTypes.contains(.hevc) {
					self.movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
				}
				let outputFileName = NSUUID().uuidString
				let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
				self.movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
				DispatchQueue.main.async {
					self.isCapturingVideo = true
				}
			} catch {
				print("Error starting movie recording: \(error)")
			}
		}
	}
	
	public func endMovieRecording() {
		self.sessionQueue.async {
			do {
				self.movieFileOutput.stopRecording()
				try self.videoDeviceInput.device.lockForConfiguration()
				if self.videoDeviceInput.device.isTorchModeSupported(self.videoDeviceInput.device.torchMode) && self.flashMode == .on {
					self.videoDeviceInput.device.torchMode = .off
					self.videoDeviceInput.device.unlockForConfiguration()
				}
				self.videoDeviceInput.device.videoZoomFactor = 1
			} catch {
				print(error)
			}
		}
		DispatchQueue.main.async {
			self.didFinishTakingContent = true
			self.isCapturingVideo = false
			self.zoomDragValueHeight = 0
		}
	}
	
	public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		DispatchQueue.main.async {
			if self.movieFileOutput.isRecording && self.currentDevicePosition == .front && self.flashMode == .on {
				self.frontFlash = Color.white
			} else {
				self.frontFlash = Color.clear
			}
		}
	}
	
	public func mergeCapturedVideos(url: URL) {
		do {
			let mainComposition = AVMutableComposition()
			
			if let videoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
				let movieAsset: AVAsset = AVAsset(url: url)
				try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: movieAsset.duration), of: movieAsset.tracks(withMediaType: .video)[0], at: insertTime)
				insertTime = CMTimeAdd(insertTime, movieAsset.duration)
				self.mutableCompTracks.append(videoTrack)
			}

//			for movie in self.capturedMovieURLs {
//				let mainComposition = AVMutableComposition()
//				let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
//				let movieAsset: AVAsset = AVAsset(url: movie)
//				try compositionVideoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: movieAsset.duration), of: movieAsset.tracks(withMediaType: .video)[0], at: insertTime)
//				insertTime = CMTimeAdd(insertTime, movieAsset.duration)
//				mutableCompTracks.append(compositionVideoTrack!)
//			}
			print("A: \(self.mutableCompTracks)")
		} catch {
			print("Error merging videos: \(error)")
		}
	}
	
	/// - Tag: DidFinishRecording
	public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
		let outputURL: URL = outputFileURL
		DispatchQueue.main.async {
			self.frontFlash = Color.clear
			self.capturedMovieURLs.append(outputURL)
			print("\(self.capturedMovieURLs)")
			
//			if !self.isCapturingVideo && !self.capturedMovieURLs.isEmpty {
				self.mergeCapturedVideos(url: outputFileURL)
//			}
		}
		var success = true
		if error != nil {
			print("Movie file finishing error: \(String(describing: error))")
			success = ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue
		}
		if success {
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					// Save the movie file to the photo library and cleanup.
					PHPhotoLibrary.shared().performChanges({
						let options = PHAssetResourceCreationOptions()
						options.shouldMoveFile = true
						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
					}, completionHandler: { success, error in
						if !success {
							print("\(self.applicationName) couldn't save the movie to your photo library: \(String(describing: error))")
						}
						self.cleanupFileManagerToSaveNewFile(outputFileURL: outputURL)
					}
					)
				} else {
					self.cleanupFileManagerToSaveNewFile(outputFileURL: outputURL)
				}
			}
		} else {
			self.cleanupFileManagerToSaveNewFile(outputFileURL: outputURL)
		}
	}
	
	private func cleanupFileManagerToSaveNewFile(outputFileURL: URL) {
		let path = outputFileURL.path
		if FileManager.default.fileExists(atPath: path) {
			do {
				try FileManager.default.removeItem(atPath: path)
			} catch {
				print("Could not remove file at url: \(outputFileURL)")
			}
		}
		
		if let currentBackgroundRecordingID = backgroundRecordingID {
			backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
			
			if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
				UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
			}
		}
	}
	
//	public func saveMovieToCameraRoll() {
//
//	}
}
