package net.xophiix
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	import mx.graphics.codec.PNGEncoder;
	
	import net.tautausan.plist.Plist10;
	
	public class SwfToAnimPlistConverter
	{
		public function SwfToAnimPlistConverter()
		{
		}
		
		public function convert(swfPath:File, outputPath:File, option:Object, callback:Function):void {								
			var enablePrefix:Boolean = option.enablePrefix;
			var dependPrefix:String = option.dependPrefix;
			if (!enablePrefix) {
				dependPrefix = "";
			}
			
			if (dependPrefix && dependPrefix.charAt(dependPrefix.length - 1) != "/") {
				dependPrefix += "/";
			}
			
			var loader:Loader = new Loader();			
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function (event:IOErrorEvent): void {
				callback(event.toString());
			});

			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (event:Event): void {
				var swf:MovieClip = event.target.content as MovieClip;
				var pureFileName:String = swfPath.name.replace("." + swfPath.extension, "");						
				
				var fileList:Vector.<File> = new Vector.<File>();						
				if (swf.totalFrames > 0) {
					var animation = new Object;							
					animation.properties = new Object;
					// always use format 2
					animation.properties.format = 2;
					animation.properties.spritesheets = [
						dependPrefix + pureFileName + ".meta" + (enablePrefix ? "" : ".plist")
					];
					
					animation.animations = new Object;
					animation.animations.main = new Object;
					animation.animations.main.delayPerUnit = 1.0 / swf.loaderInfo.frameRate;
					animation.animations.main.frames = new Array();
					
					var lastBitmapData:BitmapData;
					var lastFrameIndex:int = 1;
					var actualFrameIndex:int = 0;
					var lastFrame:Object;
					
					do {
						var bitmapData:BitmapData = new BitmapData(swf.width, swf.height, true, 0);						
						bitmapData.draw(swf);
						
						if (lastBitmapData) {
							var lastBitmapPixels:ByteArray = lastBitmapData.getPixels(lastBitmapData.rect);
							var curBitmapPixels:ByteArray = bitmapData.getPixels(bitmapData.rect);
							
							var pixelSame:Boolean = true;
							if (lastBitmapPixels.length == curBitmapPixels.length) {
								var len:uint = lastBitmapPixels.length;
								for (var i:uint = 0; i < len; ++i) {
									if (lastBitmapPixels[i] != curBitmapPixels[i]) {
										pixelSame = false;
										break;
									}
								}
							} else {
								pixelSame = false;
							}
						}
						
						if (pixelSame) {
							if (swf.currentFrame == swf.totalFrames) {
								break;
							}
							
							swf.nextFrame();
							continue;
						} else {
							lastBitmapData = bitmapData;
						}
						
						if (lastFrame) {
							lastFrame.delayUnits = swf.currentFrame - lastFrameIndex + 1;	
						}
						
						var frame:Object = new Object;														
						frame.spriteframe = pureFileName + actualFrameIndex.toString() + ".png";
						animation.animations.main.frames.push(frame);							
						
						lastFrame = frame;
						lastFrameIndex = swf.currentFrame;
						
						++actualFrameIndex;
						
						// save bitmapdata as png
						var fs:FileStream = new FileStream;
						var pngEncoder:PNGEncoder = new PNGEncoder;
						var pngData:ByteArray = pngEncoder.encode(bitmapData);
						var file:File = new File(outputPath.nativePath + "/" + frame.spriteframe);
						
						fs.open(file, FileMode.WRITE);
						fs.writeBytes(pngData);
						fs.close();
						
						fileList.push(file);
						
						if (swf.currentFrame == swf.totalFrames) {
							break;
						}
						
						swf.nextFrame();
					} while (swf.currentFrame <= swf.totalFrames);
					
					if (lastFrame) {
						lastFrame.delayUnits = swf.currentFrame - lastFrameIndex + 1;
						lastFrame = null;
					}
				} else {
					callback("swf contains no frame: " + swfPath.name);
					return;
				}
				
				if (!fileList.length) {
					callback("swf contains no valid frame: " + swfPath.name);
					return;
				}
				
				// pack pngs to spritesheet
				packSpritesheet(animation, fileList, outputPath, enablePrefix, dependPrefix, pureFileName, callback);
			});
			
			loader.load(new URLRequest("file://" + swfPath.nativePath));
		}
		
		private function packSpritesheet(animation:Object, fileList:Vector.<File>, outputPath:File, enablePrefix:Boolean, dependPrefix:String, pureFileName:String, callback:Function):void {
			if(!NativeProcess.isSupported) {
				callback("native process not supported!");
				return;
			}
			
			var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			var file:File = File.applicationDirectory.resolvePath("sprite-mapper");
			nativeProcessStartupInfo.executable = file;
			
			var processArgs:Vector.<String> = new Vector.<String>();	
			processArgs.push(outputPath.nativePath);
			for (var i:uint = 0; i < fileList.length; ++i) {					
				processArgs.push(fileList[i].name);
			}
			
			processArgs.push("--output=" + pureFileName + ".packed.png");
			processArgs.push("--zwoptex2=" + pureFileName + ".meta.plist");
			processArgs.push("--trim");
			processArgs.push("--algorithm=shelf");
			processArgs.push("--keep-dir");
			
			nativeProcessStartupInfo.arguments = processArgs;
			trace(nativeProcessStartupInfo.executable.nativePath, processArgs.join(" "));
			
			var process:NativeProcess = new NativeProcess();
			process.start(nativeProcessStartupInfo);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
			process.addEventListener(NativeProcessExitEvent.EXIT, onExit);
			process.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
			process.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
			
			function onOutputData(event:ProgressEvent):void {
				trace("StandardOut: ", process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)); 
			}
			
			function onErrorData(event:ProgressEvent):void {
				trace("ERROR -", process.standardError.readUTFBytes(process.standardError.bytesAvailable));					
			}
			
			function onIOError(event:IOErrorEvent):void {
				trace(event.toString());
			}
			
			function onExit(event:NativeProcessExitEvent):void {
				trace("Process exited with ", event.exitCode);
				if (0 == event.exitCode) {					
					if (enablePrefix) {
						// adjust textureFileName with prefix in xxx.packed.plist
						var loader:URLLoader = new URLLoader();						
						var metaPlistPath:String = outputPath.resolvePath(pureFileName + ".meta.plist").url;
						loader.load(new URLRequest(metaPlistPath));
						loader.addEventListener(Event.COMPLETE, function (event:Event):void {
							var packedMetaPlist:Plist10 = new Plist10;
							var packedMeta:Object = packedMetaPlist.decode(event.target.data);
							var orgTextureName:String = packedMeta.metadata.textureFileName;							
							packedMeta.metadata.textureFileName = dependPrefix + orgTextureName.replace(".png", "");
							
							if (!savePlist(packedMeta, metaPlistPath)) {
								callback("rewrite packed meta plist file failed");
								return;
							}
							
							for (var i:uint = 0; i < fileList.length; ++i) {					
								fileList[i].deleteFile();
							}
							
							if (savePlist(animation, outputPath.resolvePath(pureFileName + ".anim.plist").url)) {
								callback();
							} else {
								callback("write animation plist file failed");
							}	
						});	
						
						loader.addEventListener(IOErrorEvent.IO_ERROR, function (event:Event):void {
							callback("load " + pureFileName + ".packed.plist failed: " + event.toString());
						});
					} else {
						if (savePlist(animation, outputPath.resolvePath(pureFileName + ".anim.plist").url)) {
							callback();
						} else {
							callback("write animation plist file failed");
						}
					}					
				} else {
					callback("pack spritesheet failed: " + event.exitCode);
				}
			}
		}
		
		private function savePlist(object:Object, outputFileName:String):Boolean {
			if (!object) {
				return false;
			}
			
			var fs:FileStream = new FileStream;				
			var file:File = new File(outputFileName);
			
			fs.open(file, FileMode.WRITE);									
			fs.writeUTFBytes((new Plist10).encode(object));
			fs.close();			
			return true;
		}
	}
}