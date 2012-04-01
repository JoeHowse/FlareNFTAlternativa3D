/*

FlareNFTAlternativa3D.as -- A demo, integrating flare*nft and Alternativa3D.

version 0.3.0, January 7th, 2012

Copyright (c) 2011-2012 Joseph Howse

This software is provided 'as-is', without any express or implied warranty. In
no event will the author be held liable for any damages arising from the use
of this software.

Permission is granted to anyone to use this software for any purpose, including
commercial applications, and to alter it and redistribute it freely, subject to
the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim
   that you wrote the original software. If you use this software in a product,
   an acknowledgment in the product documentation would be appreciated but is
   not required.

2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.

Joseph Howse josephhowse@nummist.com

*/

package  
{
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.View;
	
	import at.imagination.flare.FlareNFT;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	
	[SWF(width='640', height='480', backgroundColor='#ffffff', frameRate='60')]
	public class FlareNFTAlternativa3D extends Sprite
	{
		private var video_:Video;
		private var videoBitmapData_:BitmapData;
		private var videoBitmapDataDrawMatrix_:Matrix;
		private var flareNFT_:FlareNFT;
		private var targets_:Dictionary = new Dictionary();
		
		private var scene_:Object3D = new Object3D();
		private var camera3D_:Camera3D = new Camera3D(1, 10000);
		private var stage3D_:Stage3D;
		
		private var targetMatrixRawData_:Vector.<Number> = new Vector.<Number>(16);
		private var targetsFoundLastFrame_:Boolean = false;
		
		
		// Flash video camera initialization arguments.
		private static const PREFERRED_VIDEO_CAMERA_WIDTH:int = 640;
		private static const PREFERRED_VIDEO_CAMERA_HEIGHT:int = 480;
		private static const PREFERRED_VIDEO_CAMERA_FPS:Number = 60;
		private static const FAVOR_AREA:Boolean = true;
		
		// flare*nft initialization arguments.
		private static const INIT_FROM_BUNDLED_SWF:Boolean = false;
		private static const DATA_FOLDER:String = "data";
		private static const FEATURE_SET_TEXT_FILE:String = "featureSet.ini";
		private static const FEATURE_SET_BINARY_FILE:String = "featureSet.swf";
		private static const CAM_FILE:String =
			PREFERRED_VIDEO_CAMERA_WIDTH / PREFERRED_VIDEO_CAMERA_HEIGHT < 14/9 ?
				"cam.ini" // optimized for 4:3 aspect ratio
			:
				"camWideFormat.ini" // optimized for 16:9 aspect ratio
			;
		private static const MULTI_TARGETS:Boolean = false;
		private static const LOG_LEVEL:uint = 3;
		
		// Argument for applying mirroring (horizontal flip), or not.
		// Mirroring, if applied at all, is applied ONLY to the video and top-level target nodes.
		// Other nodes, including target subnodes, are NOT mirrored.
		private static const MIRROR_VIDEO:Boolean = false;
		
		// Argument for scaling the imported 3D models.
		// The application's units are related to a video camera's pixel pitch (and field of view).
		// These units are typically much smaller than those used by 3D artists.
		// Thus, the import scaling factor is large.
		private static const IMPORT_SCALING_FACTOR:Number = 100;
		
		// Argument for showing or hiding Alternativa3D's built-in logo.
		// See the Alternativa3D license agreement for branding requirements.
		private static const SHOW_ALTERNATIVAPLATFORM_LOGO:Boolean = true;
		
		// Argument for showing or hiding the performance profiling diagram.
		private static const SHOW_PROFILING_DIAGRAM:Boolean = true;
		
		
		public function FlareNFTAlternativa3D()
		{
			super();
			
			// Listen for being added to the 2D stage.
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
		
		
		private function onAddedToStage(event:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			
			// Configure the 2D stage.
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			// Get the 3D stage.
			stage3D_ = stage.stage3Ds[0];
			
			// Start loading the camera configuration file.
			var loader:URLLoader = new URLLoader(); 
			loader.dataFormat = URLLoaderDataFormat.TEXT; 
			loader.addEventListener(Event.COMPLETE, onCamFileLoadComplete); 
			loader.load(new URLRequest(DATA_FOLDER + "/" + CAM_FILE));
		}
		
		private function onCamFileLoadComplete(event:Event):void
		{
			var loader:URLLoader = event.target as URLLoader;
			loader.removeEventListener(Event.COMPLETE, onCamFileLoadComplete); 
			
			// Parse the camera configuration file by splitting on whitespace.
			var camINIArgs:Array = loader.data.toString().split(/(\s)/);
			
			// Omit parsing results that are empty or whitespace.
			camINIArgs = camINIArgs.filter
			(
				function(element:String, i:uint, array:Array):Boolean
				{
					return element.match(/(^\s*$)/) ? false : true;
				}
			);
			
			// Read the viewspace frame dimensions and focal length from the parsing results.
			var viewspaceFrameWidth:Number = camINIArgs[1];
			var viewspaceFrameHeight:Number = camINIArgs[2];
			var viewspaceFocalLength:Number = camINIArgs[5];
			
			// Create the video camera.
			var videoCamera:Camera = Camera.getCamera();
			if(!videoCamera)
			{
				trace("FlareNFTAlternativa3D: No video camera found.");
			}
			
			// Configure the video camera's dimensions and FPS.
			videoCamera.setMode(PREFERRED_VIDEO_CAMERA_WIDTH, PREFERRED_VIDEO_CAMERA_HEIGHT, PREFERRED_VIDEO_CAMERA_FPS, FAVOR_AREA);
			
			// Get the video camera's actual dimensions, which may differ from the preferred dimensions.
			var videoCameraWidth:Number = videoCamera.width;
			var videoCameraHeight:Number = videoCamera.height;
			
			// Create the video and attach the video camera to it.
			// For efficiency, the video has the same dimensions as the video camera.
			// Later, the video will be scaled to fill the 2D stage.
			video_ = new Video(videoCameraWidth, videoCameraHeight);
			video_.attachCamera(videoCamera);
			
			// Create the bitmap data that will be used to marshal each video frame to flare*nft.
			videoBitmapData_ = new BitmapData(viewspaceFrameWidth, viewspaceFrameHeight, false, 0xFFFFFF);
			
			// Create the matrix that will be used to scale each marshalled video frame.
			// This scaling can greatly reduce the burden on flare*nft, which does not need high-res input.
			// ex. Downscaling 1240x720 to 320x180 cuts pixel input to flare*nft by a factor of 16.
			videoBitmapDataDrawMatrix_ = new Matrix
			(
				viewspaceFrameWidth / videoCameraWidth,
				0,
				0,
				viewspaceFrameHeight / videoCameraHeight,
				0,
				0
			);
			
			// Create and initialize the FlareNFT tracker.
			flareNFT_ = new FlareNFT();
			flareNFT_.setLogger(this, log, LOG_LEVEL);
			log(0, "libFlareNFT version " + flareNFT_.getVersion());
			if(INIT_FROM_BUNDLED_SWF)
			{
				flareNFT_.initFromBundledSWF
				(
					stage,
					viewspaceFrameWidth,
					viewspaceFrameHeight,
					videoCamera.fps,
					DATA_FOLDER + "/" + FEATURE_SET_BINARY_FILE,
					MULTI_TARGETS,
					onFlareNFTInitDone
				);
			}
			else
			{
				flareNFT_.init
				(
					stage,
					DATA_FOLDER,
					CAM_FILE,
					viewspaceFrameWidth,
					viewspaceFrameHeight,
					videoCamera.fps,
					FEATURE_SET_TEXT_FILE,
					MULTI_TARGETS,
					onFlareNFTInitDone
				);
			}
			
			// Configure the 3D camera to render to a texture in the 2D context.
			// This texture's background is transparent, so the video shows through.
			camera3D_.view = new View
			(
				stage.stageWidth, // width
				stage.stageHeight, // height
				true, // renderToBitmap
				0, // backgroundColor
				0, // backgroundAlpha
				4 // antiAlias
			);
			
			if(!SHOW_ALTERNATIVAPLATFORM_LOGO)
			{
				// Hide the AlternativaPlatform logo.
				camera3D_.view.hideLogo();
			}
			
			// Add the video and 3D scene to the 2D scene.
			addChild(video_);
			addChild(camera3D_.view);
			
			if(SHOW_PROFILING_DIAGRAM)
			{
				// Add the profiling diagram to the 2D scene.
				addChild(camera3D_.diagram);
			}
			
			// Add the 3D camera to the 3D scene.
			scene_.addChild(camera3D_);
			
			// Configure the 3D camera's FOV to accomodate flare*nft's units.
			// Note that "fov" in Alternativa3D is diagonal FOV.
			// For perspective projection:
			//    fovDiagonal = 2 * atan(frameSizeDiagonal / (2 * focalLength))
			camera3D_.fov = 2 * Math.atan(Math.sqrt(Math.pow(viewspaceFrameWidth, 2) + Math.pow(viewspaceFrameHeight, 2)) / (2 * viewspaceFocalLength));
		}
		
		private function log(level:int, message:String):void
		{
			trace("FlareNFT: [" + level + "] " + message);
		}
		
		private function onFlareNFTInitDone():void
		{
			// Listen for and request the 3D stage's graphics context.
			stage3D_.addEventListener(Event.CONTEXT3D_CREATE, onContextCreate);
			stage3D_.requestContext3D();
		}
		
		private function onContextCreate(event:Event):void
		{
			stage3D_.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreate);
			
			// Set up the targets and models.
			
			// Create the matrix that will represent each model's offset from the target position.
			var offsetMatrix:Matrix3D = new Matrix3D();
			offsetMatrix.appendTranslation(0, 0, 0.5);
			offsetMatrix.appendScale(IMPORT_SCALING_FACTOR, IMPORT_SCALING_FACTOR, IMPORT_SCALING_FACTOR);
			
			var model:SimpleModel;
			var i:Number = 0;
			for each(var file:String in ["model_austria.dae", "model_vienna.dae", "model_graz.dae"])
			{
				// Create the model.
				model = new SimpleModel(stage3D_.context3D, DATA_FOLDER, file, offsetMatrix);
				
				// Associate the model with one of the target IDs.
				targets_[i++] = model;
				
				// Add the model to the 3D scene.
				scene_.addChild(model);
			}
			
			
			// Listen for frame updates.
			stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			
			// Listen for resize events.
			stage.addEventListener(Event.RESIZE, onResize);
			
			// Handle any resize event that may have already occured.
			onResize();
		}
		
		private function onEnterFrame(event:Event):void
		{
			var target:Object3D;
				
			// By default, hide all targets.
			// Later, tracked targets will be unhidden.
			for each(target in targets_)
			{
				target.visible = false;
			}
			
			// Update and get the tracker results.
			videoBitmapData_.draw(video_, videoBitmapDataDrawMatrix_);
			
			var numTargetsFound:uint = flareNFT_.update(videoBitmapData_);
			var trackerResults:ByteArray = flareNFT_.getTrackerResults();
			
			// Iterate over all tracked targets.
			for(var i:uint = 0; i < numTargetsFound; i++)
			{
				// Read the target type and ID.
				var targetType:int = trackerResults.readInt();
				var targetID:int = trackerResults.readInt();
				
				// Get the target.
				target = targets_[targetID];
				
				if(target)
				{
					// Read the new matrix data.
					if(MIRROR_VIDEO)
					{
						targetMatrixRawData_[ 0] =  trackerResults.readFloat();
						targetMatrixRawData_[ 1] = -trackerResults.readFloat(); // mirrored roll
						targetMatrixRawData_[ 2] = -trackerResults.readFloat(); // mirrored yaw
						targetMatrixRawData_[ 3] =  trackerResults.readFloat();
						
						targetMatrixRawData_[ 4] = -trackerResults.readFloat(); // mirrored roll
						targetMatrixRawData_[ 5] =  trackerResults.readFloat();
						targetMatrixRawData_[ 6] =  trackerResults.readFloat();
						targetMatrixRawData_[ 7] =  trackerResults.readFloat();
						
						targetMatrixRawData_[ 8] = -trackerResults.readFloat(); // mirrored yaw
						targetMatrixRawData_[ 9] =  trackerResults.readFloat();
						targetMatrixRawData_[10] =  trackerResults.readFloat();
						targetMatrixRawData_[11] =  trackerResults.readFloat();
						
						targetMatrixRawData_[12] = -trackerResults.readFloat(); // mirrored x
						targetMatrixRawData_[13] =  trackerResults.readFloat();
						targetMatrixRawData_[14] =  trackerResults.readFloat();
						targetMatrixRawData_[15] =  trackerResults.readFloat();
					}
					else
					{
						targetMatrixRawData_[ 0] =  trackerResults.readFloat();
						targetMatrixRawData_[ 1] =  trackerResults.readFloat();
						targetMatrixRawData_[ 2] =  trackerResults.readFloat();
						targetMatrixRawData_[ 3] =  trackerResults.readFloat();
						
						targetMatrixRawData_[ 4] =  trackerResults.readFloat();
						targetMatrixRawData_[ 5] =  trackerResults.readFloat();
						targetMatrixRawData_[ 6] =  trackerResults.readFloat();
						targetMatrixRawData_[ 7] =  trackerResults.readFloat();
						
						targetMatrixRawData_[ 8] =  trackerResults.readFloat();
						targetMatrixRawData_[ 9] =  trackerResults.readFloat();
						targetMatrixRawData_[10] =  trackerResults.readFloat();
						targetMatrixRawData_[11] =  trackerResults.readFloat();
						
						targetMatrixRawData_[12] =  trackerResults.readFloat();
						targetMatrixRawData_[13] = trackerResults.readFloat();
						targetMatrixRawData_[14] = trackerResults.readFloat();
						targetMatrixRawData_[15] = trackerResults.readFloat();
					}
					
					// Update the target's matrix.
					target.matrix = new Matrix3D(targetMatrixRawData_);
					
					// Show the target.
					target.visible = true;
				}
			}
			
			var targetsFoundThisFrame:Boolean = numTargetsFound > 0;
			if(targetsFoundThisFrame || targetsFoundLastFrame_)
			{
				// Targets were found this frame or last frame.
				
				// Redraw the 3D scene, since it is changing.
				camera3D_.render(stage3D_);
				
				// Remember whether targets were found this frame.
				targetsFoundLastFrame_ = targetsFoundThisFrame;
			}
		}
		
		private function onResize(event:Event = null):void
		{
			// Get the 2D stage dimensions.
			var stageWidth:int = stage.stageWidth;
			var stageHeight:int = stage.stageHeight;
			
			// Resize the viewport.
			camera3D_.view.width = stageWidth;
			camera3D_.view.height = stageHeight;
			
			// Resize the video.
			video_.width = stageWidth;
			video_.height = stageHeight;
			
			if(MIRROR_VIDEO)
			{
				// Create and apply the video's mirror matrix, which is width-dependent.
				var mirrorMatrix:Matrix = new Matrix();
				mirrorMatrix.a = -1;
				mirrorMatrix.tx = stageWidth;
				video_.transform.matrix = mirrorMatrix;
			}
		}
	}
}