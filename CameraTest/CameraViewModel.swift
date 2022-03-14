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
	@Published var capturedImage: UIImage? = nil
	@Published var capturedMovieURLs: [URL] = []
	@Published var currentDevicePosition: AVCaptureDevice.Position = .back
	@Published var didFinishSavingContent: Bool = false
	@Published var didFinishTakingContent: Bool = false
	@Published var flashMode: AVCaptureDevice.FlashMode = .off
	@Published var focusImage: String?
	@Published var isCapturingPhoto: Bool = false
	@Published var isCapturingVideo: Bool = false
	@Published var isMultiCaptureEnabled: Bool = false
	@Published var movieFileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	@Published var multiCapturedImages: [UIImage] = []
	@Published var photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
	@Published var preferredStartingCameraPosition: AVCaptureDevice.Position = .back
	@Published var preferredStartingCameraType: AVCaptureDevice.DeviceType = .builtInDualCamera
	@Published var session = AVCaptureSession()
	@Published var showCapturedContentReview: Bool = false
	@Published var tappedFocusPoint: CGPoint? = nil
	@Published var recordTimerCount: CGFloat = 0.0
	@Published var videoGravity: AVLayerVideoGravity = .resizeAspectFill
	@Published var videoPlayerURL: URL? = nil
	@Published var backCamVideoQuality: AVCaptureSession.Preset = .photo
	@Published var frontCamVideoQuality: AVCaptureSession.Preset = .high
	@Published var zoomAmount: CGFloat = 1
	private var audioDeviceInput: AVCaptureDeviceInput!
	private var preferredRotatedCameraPosition: AVCaptureDevice.Position = .front
	private var preferredRotatedCameraType: AVCaptureDevice.DeviceType = .builtInTrueDepthCamera
	private var setupResult: SessionSetupResult = .success
	private var videoDeviceInput: AVCaptureDeviceInput!
	private var zoomDragValueHeight: CGFloat = 0
	private let sessionQueue = DispatchQueue(label: "session queue")
	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}
	
	public func goBackToCameraFromReview() {
		DispatchQueue.main.async {
			self.checkForCameraPermissions()
			self.didFinishTakingContent = false
			self.isMultiCaptureEnabled = false
			self.multiCapturedImages = []
			self.capturedImage = nil
			self.videoPlayerURL = nil
			self.didFinishSavingContent = false
			self.showCapturedContentReview = false
		}
	}
	
	public func checkForCameraPermissions() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
			case .authorized:
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
		if self.currentDevicePosition == .back {
			self.session.sessionPreset = self.backCamVideoQuality
		} else {
			self.session.sessionPreset = self.frontCamVideoQuality
		}
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
				try self.videoDeviceInput.device.lockForConfiguration()
				self.videoDeviceInput.device.exposureMode = .continuousAutoExposure
				if self.videoDeviceInput.device.isFocusPointOfInterestSupported {
					self.videoDeviceInput.device.focusMode = .continuousAutoFocus
				}
				if self.videoDeviceInput.device.isLowLightBoostSupported {
					self.videoDeviceInput.device.automaticallyEnablesLowLightBoostWhenAvailable = true
				}
				self.videoDeviceInput.device.automaticallyAdjustsVideoHDREnabled = true
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
			DispatchQueue.main.async {
				if self.isCapturingVideo {
					DispatchQueue.main.async {
						self.movieFileOutput.stopRecording()
						self.session.stopRunning()
						self.configureSession()
						self.startMovieRecording()
					}
				} else {
					DispatchQueue.main.async {
						self.configureSession()
					}
				}
			}
		}
	}
	
	public func videoZoom(translHeight: CGFloat) {
		do {
			let captureDevice = self.videoDeviceInput.device
			try captureDevice.lockForConfiguration()
			let maxZoomFactor: CGFloat = captureDevice.activeFormat.videoMaxZoomFactor
			DispatchQueue.main.async {
				let value = -translHeight
				var rawZoomFactor: CGFloat = 0
				if !self.movieFileOutput.isRecording {
					self.zoomDragValueHeight = value
					rawZoomFactor = ((self.zoomDragValueHeight/UIScreen.main.bounds.height) * maxZoomFactor) / 4
				} else if self.zoomDragValueHeight != 0 && self.movieFileOutput.isRecording {
					rawZoomFactor = (((self.zoomDragValueHeight+value)/UIScreen.main.bounds.height) * maxZoomFactor) / 4
				} else {
					rawZoomFactor = ((value/UIScreen.main.bounds.height) * maxZoomFactor) / 4
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
	
	public func tapToFocus(tapLocation: CGPoint, viewSize: CGRect) {
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
			device.exposureMode = .continuousAutoExposure
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
			do {
				DispatchQueue.main.async {
					self.isCapturingPhoto = true
				}
				let captureDevice = self.videoDeviceInput.device
				try captureDevice.lockForConfiguration()
				let photoSettings = AVCapturePhotoSettings()
				if self.videoDeviceInput.device.isFlashAvailable {
					photoSettings.flashMode = self.flashMode
				}
				self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
			} catch {
				print("Error taking photo: \(error)")
			}
		}
	}
	
	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		guard error == nil else {
			print("Error capturing photo: \(error!)")
			return
		}

		if let photoData = photo.fileDataRepresentation() {
			if let dataProvider: CGDataProvider = CGDataProvider(data: photoData as CFData) {
				if let cgImageRef: CGImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
					DispatchQueue.main.async {
						if self.backCamVideoQuality == .photo && self.currentDevicePosition == .back {
							self.cropImage(image: cgImageRef) { croppedImage in
								self.sendImagesToReview(image: croppedImage)
							}
						} else {
							var uiImage: UIImage = UIImage()
							if self.currentDevicePosition == .front {
								uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: .leftMirrored)
							} else {
								uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: .right)
							}
							self.sendImagesToReview(image: uiImage)
						}
					}
				}
			}
		}
	}
	
	private func cropImage(image: CGImage, completion: @escaping (_ croppedImage: UIImage) -> Void) {
		let aspectRatio: CGFloat = 1920 / 1080
		let cropRectY: CGFloat = ((1920 - 1080) / aspectRatio) - 100
		let cropRect = CGRect(x: 0, y: cropRectY, width: CGFloat(image.width), height: CGFloat(image.width) / aspectRatio)
		if let croppedImage: CGImage = image.cropping(to: cropRect) {
			var uiImage: UIImage = UIImage()
			if self.currentDevicePosition == .front {
				uiImage = UIImage(cgImage: croppedImage, scale: 1.0, orientation: .leftMirrored)
			} else {
				uiImage = UIImage(cgImage: croppedImage, scale: 1.0, orientation: .right)
			}
			completion(uiImage)
		}
	}
	
	private func sendImagesToReview(image: UIImage) {
		if self.isMultiCaptureEnabled {
			self.multiCapturedImages.append(image)
			if self.multiCapturedImages.count == 10 {
				self.didFinishTakingContent = true
				self.showCapturedContentReview = true
			}
		} else {
			self.capturedImage = image
			self.didFinishTakingContent = true
			self.showCapturedContentReview = true
			self.isCapturingPhoto = false
			self.videoDeviceInput.device.videoZoomFactor = 1
		}
		self.isCapturingPhoto = false
	}
	
	public func savePhoto(_ image: UIImage) {
		UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingWithError(_:didFinishSavingWithError:contextInfo:)), nil)
	}
	
	@objc private func didFinishSavingWithError(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
		if let error = error {
			print(error)
		} else {
			DispatchQueue.main.async {
				self.didFinishSavingContent = true
			}
		}
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
					if self.recordTimerCount <= 1.0 {
						self.isCapturingVideo = true
					}
				}
			} catch {
				print("Error starting movie recording: \(error)")
			}
		}
	}
	
	public func endMovieRecording() {
		DispatchQueue.main.async {
			self.didFinishTakingContent = true
			self.isCapturingVideo = false
			self.zoomDragValueHeight = 0
		}
		self.sessionQueue.async {
			do {
				self.movieFileOutput.stopRecording()
				try self.videoDeviceInput.device.lockForConfiguration()
				if self.videoDeviceInput.device.isTorchModeSupported(self.videoDeviceInput.device.torchMode) && self.flashMode == .on {
					self.videoDeviceInput.device.torchMode = .off
				}
				self.videoDeviceInput.device.videoZoomFactor = 1
				self.videoDeviceInput.device.unlockForConfiguration()
			} catch {
				print("Error ending movie recording: \(error)")
			}
		}
	}
	
//	private func cropVideo( _ outputFileUrl: URL, completion: @escaping (_ newUrl: URL) -> Void) {
//		// Get input clip
////		let videoAsset: AVAsset = AVAsset(url: outputFileUrl)
////		let clipVideoTrack = videoAsset.tracks(withMediaType: .video).first! as AVAssetTrack
////
////		// Make video to square
////		let aspectRatio: CGFloat = 1920 / 1080
////		let videoComposition = AVMutableVideoComposition()
////		videoComposition.renderSize = CGSize(width: clipVideoTrack.naturalSize.width, height: clipVideoTrack.naturalSize.width / aspectRatio)
////		videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
////
////		// Rotate to portrait
//////		let transformer = AVMutableVideoCompositionLayerInstruction( assetTrack: clipVideoTrack)
//////		let transform1 = CGAffineTransform(translationX: clipVideoTrack.naturalSize.height, y: -(clipVideoTrack.naturalSize.width - clipVideoTrack.naturalSize.height ) / 2 )
//////		let transform2 = transform1.rotated(by: CGFloat(.pi / 2))
//////		transformer.setTransform( transform2, at: kCMTimeZero)
////
//////		let mainInstruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
//////		mainInstruction.timeRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
//////		instruction.layerInstructions = [mainInstruction]
//////		videoComposition.instructions = [instruction]
////
////		// Export
////		let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
////		let dateFormatter = DateFormatter()
////		dateFormatter.dateStyle = .long
////		dateFormatter.timeStyle = .long
////		let date = dateFormatter.string(from: NSDate() as Date)
////		let savePath = (documentDirectory as NSString).appendingPathComponent("eventSocial-\(date).mp4")
////		let url = NSURL(fileURLWithPath: savePath)
////		if let exporter = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPreset1920x1080) {
////			exporter.videoComposition = videoComposition
////			exporter.outputURL = url as URL
////			exporter.outputFileType = .mp4
////			exporter.exportAsynchronously {
////				DispatchQueue.main.async {
////					if let url = exporter.outputURL {
////						completion(url)
////					}
////				}
////			}
////		}
//		let item = AVPlayerItem(url: outputFileUrl)
//
//		let aspectRatio: CGFloat = 1920 / 1080
//		let cropRectY: CGFloat = ((1920 - 1080) / aspectRatio) - 100
//		let cropRect = CGRect(x: 0, y: cropRectY, width: CGFloat(item.presentationSize.width), height: CGFloat(item.presentationSize.width) / aspectRatio)
//
//		let cropScaleComposition = AVMutableVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: { request in
//			let cropFilter = CIFilter(name: "CICrop")! //1
//			cropFilter.setValue(request.sourceImage, forKey: kCIInputImageKey) //2
//			cropFilter.setValue(CIVector(cgRect: cropRect), forKey: "inputRectangle")
//
//			let imageAtOrigin = cropFilter.outputImage!.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y)) //3
//			request.finish(with: imageAtOrigin, context: nil) //4
//		})
//
//		cropScaleComposition.renderSize = cropRect.size //5
//		item.videoComposition = cropScaleComposition  //6
//
//		let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//		let dateFormatter = DateFormatter()
//		dateFormatter.dateStyle = .long
//		dateFormatter.timeStyle = .long
//		let date = dateFormatter.string(from: NSDate() as Date)
//		let savePath = (documentDirectory as NSString).appendingPathComponent("eventSocial-\(date).mp4")
//		let url = NSURL(fileURLWithPath: savePath)
//
//		if let exporter = AVAssetExportSession(asset: item, presetName: AVAssetExportPreset1920x1080) {
//			exporter.outputURL = url as URL
//			exporter.outputFileType = .mp4
//			exporter.shouldOptimizeForNetworkUse = true
//			exporter.videoComposition = mainComposition
//			exporter.exportAsynchronously {
//				if let url = exporter.outputURL {
//					completion(url)
//				} else if let error = exporter.error {
//					print("Merge exporter error: \(error)")
//				}
//			}
//		}
//	}
	
	public func mergeCapturedVideos(completion: @escaping (_ completedMovieURL: URL) -> Void) {
		let mixComposition = AVMutableComposition()
		let movieAssets: [AVAsset] = self.capturedMovieURLs.map({ AVAsset(url: $0) })
		var insertTime: CMTime = CMTime.zero
		var layerInstructionsArray: [AVVideoCompositionLayerInstruction] = []
		for movieAsset in movieAssets {
			do {
				if let compositionVideoTrack: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {
					
					let tracks: [AVAssetTrack] = movieAsset.tracks(withMediaType: .video)
					let assetTrack: AVAssetTrack = tracks[0] as AVAssetTrack
					
					compositionVideoTrack.preferredTransform = assetTrack.preferredTransform
					let transforms = assetTrack.preferredTransform
					
					try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: movieAsset.duration), of: assetTrack, at: insertTime)
					let videoInstruction: AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
					videoInstruction.setTransform(transforms, at: .zero)
					
					if movieAsset != movieAssets.last {
						videoInstruction.setOpacity(0.0, at: movieAsset.duration)
					}
					layerInstructionsArray.append(videoInstruction)
					insertTime = CMTimeAdd(insertTime, movieAsset.duration)
				}
			} catch let error as NSError {
				print("Error merging movies: \(error)")
			}
		}
		
		let mainInstruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
		mainInstruction.timeRange = CMTimeRange(start: .zero, duration: insertTime)
		mainInstruction.layerInstructions = layerInstructionsArray
		
		let mainComposition: AVMutableVideoComposition = AVMutableVideoComposition()
		mainComposition.instructions = [mainInstruction]
		mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
		mainComposition.renderSize = CGSize(width: 1080, height: 1920)
		
		let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .long
		let date = dateFormatter.string(from: NSDate() as Date)
		let savePath = (documentDirectory as NSString).appendingPathComponent("eventSocial-\(date).mp4")
		let url = NSURL(fileURLWithPath: savePath)

		if let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPreset1920x1080) {
			exporter.outputURL = url as URL
			exporter.outputFileType = .mp4
			exporter.shouldOptimizeForNetworkUse = true
			exporter.videoComposition = mainComposition
			exporter.exportAsynchronously {
				if let url = exporter.outputURL {
					completion(url)
				} else if let error = exporter.error {
					print("Merge exporter error: \(error)")
				}
			}
		}
	}
	
	/// - Tag: DidFinishRecording
	public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//		if self.currentDevicePosition == .back {
//			self.cropVideo(outputFileURL) { newUrl in
//				self.capturedMovieURLs.append(newUrl)
//				print("DS")
//			}
//		} else {
			self.capturedMovieURLs.append(outputFileURL)
//		}
		if !self.isCapturingVideo {
			if self.capturedMovieURLs.count > 1 {
				self.mergeCapturedVideos { completedMovieURL in
					DispatchQueue.main.async {
						self.videoPlayerURL = completedMovieURL
					}
				}
			} else {
				DispatchQueue.main.async {
					self.videoPlayerURL = outputFileURL
				}
			}
			DispatchQueue.main.async {
				self.capturedMovieURLs = []
				self.showCapturedContentReview = true
			}
		}
	}
	
	public func saveMovieToCameraRoll(url: URL, error: Error?, completion: @escaping (_ didSave: Bool) -> Void) {
		var success = true
		if let error = error {
			print("Movie file finishing error: \(String(describing: error))")
			success = ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue
		}
		if success {
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					PHPhotoLibrary.shared().performChanges({
						let options = PHAssetResourceCreationOptions()
						options.shouldMoveFile = true
						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .video, fileURL: url, options: options)
					}, completionHandler: { success, error in
						if !success {
							print("\(self.applicationName) couldn't save the movie to your photo library: \(String(describing: error))")
						}
						self.cleanupFileManagerToSaveNewFile(outputFileURL: url)
						completion(success)
					})
				} else {
					self.cleanupFileManagerToSaveNewFile(outputFileURL: url)
				}
			}
		} else {
			self.cleanupFileManagerToSaveNewFile(outputFileURL: url)
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
	}
}
