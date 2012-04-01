/****************************************************************************\
 *
 *  (C) 2010 by Imagination Computer Services GesmbH. All rights reserved.
 *
 *  Project: flare
 *
 *  @author Stefan Hynst
 *
\****************************************************************************/


package at.imagination.flare
{
import cmodule.libFlareNFT.CLibInit;

import flash.display.BitmapData;
import flash.display.Stage;
import flash.utils.ByteArray;

// ----------------------------------------------------------------------------

/**
 * FlareNFT is a wrapper class providing convenient methods to use the
 * functions provided by <b>libFlareNFT</b>.<br/> For an example on how to use it see
 * <code>samples/TestNFT</code>.
 */
public class FlareNFT implements IFlareTracker
{
	private var m_CLib:CLibInit;
	private var m_logFunc:Function;
	private var m_fileLoader:FilePreloader;
	private var m_trackerLib:Object;

	private var	m_stage:Stage;
	private var	m_dataPath:String;
	private var	m_featureSetFile:String;
	private var	m_camFile:String;
	private var m_camWidth:uint;
	private var m_camHeight:uint;
	private var m_camFPS:uint;
	private var m_multiTargets:Boolean;
	private var m_initDoneCB:Function;

	private var m_alcMemory:ByteArray = null;
	private var m_alcImagePointer:uint;

	// ------------------------------------------------------------------------
	
	public function FlareNFT()
	{
		m_logFunc    = null;
		m_CLib       = new CLibInit();
		m_trackerLib = m_CLib.init();
	}

	// ------------------------------------------------------------------------

	/**
	 *  Returns the version of flareNFT
	 *
	 *  @return Version number as String formatted as <code>major.minor.build</code>
	 */
	public function getVersion():String
	{
		return (m_trackerLib.getVersion());
	}

	// ------------------------------------------------------------------------
	
	/**
	 *  Sets a logging function: Use this to display logging output from libFlareNFT.
	 *  
	 *  @param obj If the logging function is a method of an object, set this to
	 *  the method's object. Otherwise pass <code>null</code>
	 *
	 *  @param logger The logging function that will be called from libFlareNFT.<br/>
	 *  The function must be of type <code>function(int,&#xA0;String):void</code>
	 *
	 *  @param level Only produce logging output for log-levels &lt;= <code>level</code>
	 */
	public function setLogger(obj:Object, logger:Function, level:uint):void
	{
		m_logFunc = logger;
		m_trackerLib.setLogger(obj, logger, level);
	}

	// ------------------------------------------------------------------------
	
	/**
	 *  Checks if the license is valid
	 *
	 *  @return true if valid, false otherwise
	 */
	public function checkLicense():Boolean
	{
		return m_trackerLib.checkLicense();
	}

	// ------------------------------------------------------------------------

	/**
	 *  Initializes the tracker. This needs to be called before <code>update()</code>
	 *  
	 *  @param dataPath Path were all the config datafiles (camera ini-file, feature-set file,
	 *  database files and pgm-files or .swf file if a bundled swf-dataset is used) are located.
	 *
	 *  @param stage The application's stage.
	 *
	 *  @param camFile Name of the camera initalization file. Can be null if a camera file is bundled in a swf-dataset.
	 *
	 *  @param camWidth Width of the camera input in pixels.
	 *
	 *  @param camHeight Height of the camera input in pixels.
	 *
	 *  @param camFPS Frames per second.
	 *
	 *  @param featureSetFile Name of the feature set file. If the name ends with a .swf, this file is treated as a bundled swf-dataset and unpacked.
	 *
	 *  @param multiTargets Set this to <code>true</code> if multiple targets should
	 *  be tracked. This is only necessary, if we want to display more than one
	 *  target at the same time.
	 *
	 *  @param initDoneCB Callback function to be invoked, when initialization has
	 *  finished. This is necessary, because all input files will be loaded
	 *  asynchronously before libFlareNFT can initialize the tracker.<br/>
	 *  The function must be of type <code>function():void</code>
	 */
	public function init(stage:Stage,
	                     dataPath:String, camFile:String, camWidth:uint, camHeight:uint, camFPS:uint,
	                     featureSetFile:String, multiTargets:Boolean,
	                     initDoneCB:Function):void
	{
		m_stage          = stage;
		m_dataPath       = dataPath;
		m_featureSetFile = featureSetFile;
		m_camFile        = camFile;
		m_camWidth       = camWidth;
		m_camHeight      = camHeight;
		m_camFPS         = camFPS;
		m_multiTargets   = multiTargets;
		m_initDoneCB     = initDoneCB;

		if (m_stage != null)
		{
			// get absolute path and replace backslashes with slashes
			var basePath:String = m_stage.loaderInfo.loaderURL.replace(/[\\]/g, "/");
			// cut off query part
			basePath = basePath.slice(0, basePath.indexOf("?"));
			// cut off file name, exclude last slash
			basePath = basePath.slice(0, basePath.lastIndexOf("/"));

			// create preloader:
			//   all files needed by libFlareNFT have to be preloaded and passed
			//   to alchemy via m_Clib.supplyFile()
			//
			m_fileLoader = new FilePreloader(fileLoadedCB);
			m_fileLoader.loadStart();
			if (m_camFile) m_fileLoader.load(m_camFile       , m_dataPath);
			if (m_featureSetFile.substr( -4) != ".swf") {
				m_fileLoader.load("flareNFT.lic"  , basePath);
				m_fileLoader.load(m_featureSetFile, m_dataPath);
			} else {
				m_fileLoader.loadDatasetSWF(m_featureSetFile, m_dataPath);
				m_featureSetFile = basename(m_featureSetFile.replace(/[\\]/g, "/"));
				m_fileLoader.loadEnd();
			}
		}
	}
	// ------------------------------------------------------------------------

	/**
	 *  Initializes the tracker. This needs to be called before <code>update()</code>
	 *  
	 *  @param camWidth Width of the camera input in pixels.
	 *
	 *  @param camHeight Height of the camera input in pixels.
	 *
	 *  @param camFPS Frames per second.
	 *
	 *  @param swfDatasetFile Name of a bundled swf-dataset file.
	 *
	 *  @param multiTargets Set this to <code>true</code> if multiple targets should
	 *  be tracked. This is only necessary, if we want to display more than one
	 *  target at the same time.
	 *
	 *  @param initDoneCB Callback function to be invoked, when initialization has
	 *  finished. This is necessary, because all input files will be loaded
	 *  asynchronously before libFlareNFT can initialize the tracker.<br/>
	 *  The function must be of type <code>function():void</code>
	 */
	public function initFromBundledSWF(stage:Stage,
	                     camWidth:uint, camHeight:uint, camFPS:uint,
	                     swfDatasetFile:String, 
						 multiTargets:Boolean,
	                     initDoneCB:Function):void
	{
		init(stage, "", null, camWidth, camHeight, camFPS, swfDatasetFile, multiTargets, initDoneCB);
	}
	// ------------------------------------------------------------------------

	/**
	 *  Returns the projection matrix. Since the camera doesn't move during tracking,
	 *  this needs to be called only once after <code>init()</code> to obtain the
	 *  projection matrix. 
	 *
	 *  @return The matrix is retured as a <code>ByteArray</code> containing 4x4 Numbers.
	 *
	 *  @example To set the projection matrix for a camera in
	 *  <a href="http://blog.papervision3d.org/">papervison3D</a>,
	 *  you would do the following:
	 *
	 *  <pre>
	 *    var mat:ByteArray = flareTrackerNFT.getProjectionMatrix();
	 *    var proj:Matrix3D = (_camera as Camera3D).projection;
	 *  &#xA0;
	 *    proj.n11 =  mat.readFloat();
	 *    proj.n21 = -mat.readFloat();
	 *    proj.n31 =  mat.readFloat();
	 *    proj.n41 =  mat.readFloat();
	 *  &#xA0;
	 *    proj.n12 =  mat.readFloat();
	 *    proj.n22 = -mat.readFloat();
	 *    proj.n32 =  mat.readFloat();
	 *    proj.n42 =  mat.readFloat();
	 *  &#xA0;
	 *    proj.n13 =  mat.readFloat();
	 *    proj.n23 = -mat.readFloat();
	 *    proj.n33 =  mat.readFloat();
	 *    proj.n43 =  mat.readFloat();
	 *  &#xA0;
	 *    proj.n14 =  mat.readFloat();
	 *    proj.n24 = -mat.readFloat();
	 *    proj.n34 =  mat.readFloat();
	 *    proj.n44 =  mat.readFloat();
	 *  </pre>
	 *
	 *  Note that the 2nd row is inverted, because we need to convert from a
	 *  right-handed coordinate system (used by flare) to a left-handed
	 *  coordinate system (used by
	 *  <a href="http://blog.papervision3d.org/">papervison3D</a>).
	 */
	public function getProjectionMatrix():ByteArray
	{
		if (! m_alcMemory) return null;

		m_alcMemory.position = m_trackerLib.getProjectionMatrixPtr();
		return m_alcMemory;
	}

	// ------------------------------------------------------------------------

	/**
	 *  This method needs to be called every frame to obtain the tracking results.
	 *  
	 *  @param image The bitmap grabbed from the camera.
	 *
	 *  @return Number of targets found.
	 */
	public function update(image:BitmapData):uint
	{
		if (! m_alcMemory) return null;

		// write to "alchemy memory"	
		m_alcMemory.position = m_alcImagePointer;
		m_alcMemory.writeBytes(image.getPixels(image.rect));	

		// returns number of targets found
		return (m_trackerLib.update());
	}

	// ------------------------------------------------------------------------

	/**
	 *  Returns the tracking results. Call this method after <code>update()</code>
	 *  found one or more targets.
	 *  
	 *  @return The tracking results are returned as a <code>ByteArray</code> structure
	 *  of the following form:
	 *  <pre>
	 *    reserved:int;            // reserved for later use
	 *    targetID:int;            // unique identifier of the target
	 *  &#xA0;
	 *    poseMatrix_11:Number;    // pose matrix: model view matrix of target in 3D space
	 *    poseMatrix_21:Number;
	 *    poseMatrix_31:Number;
	 *    poseMatrix_41:Number;
	 *  &#xA0;
	 *    poseMatrix_12:Number;
	 *    poseMatrix_22:Number;
	 *    poseMatrix_32:Number;
	 *    poseMatrix_42:Number;
	 *  &#xA0;
	 *    poseMatrix_13:Number;
	 *    poseMatrix_23:Number;
	 *    poseMatrix_33:Number;
	 *    poseMatrix_43:Number;
	 *  &#xA0;
	 *    poseMatrix_14:Number;
	 *    poseMatrix_24:Number;
	 *    poseMatrix_34:Number;
	 *    poseMatrix_44:Number;
	 *  </pre>
	 *  This structure is repeated in the <code>ByteArray</code> for every target found.
	 *
	 *  @example This example shows how the tracker results can be parsed.
	 *  <pre>
	 *    var targetID:int;
	 *    var mat:Matrix3D = new Matrix3D();
	 *    var numTargets:uint = flareTrackerNFT.update(bitmap);
	 *    var targetData:ByteArray = flareTrackerNFT.getTrackerResults();
     *  &#xA0;
	 *    // iterate over all visible targets
	 *    for (var i:uint = 0; i &lt; numTargets; i++)
	 *    {
	 *      targetData.readInt();		// unused
	 *      targetID = targetData.readInt();
     *  &#xA0;
	 *      // read pose matrix (= model view matrix)
	 *      mat.n11 =  targetData.readFloat();
	 *      mat.n21 = -targetData.readFloat();
	 *      mat.n31 =  targetData.readFloat();
	 *      mat.n41 =  targetData.readFloat();
     *  &#xA0;
	 *      mat.n12 =  targetData.readFloat();
	 *      mat.n22 = -targetData.readFloat();
	 *      mat.n32 =  targetData.readFloat();
	 *      mat.n42 =  targetData.readFloat();
     *  &#xA0;
	 *      mat.n13 =  targetData.readFloat();
	 *      mat.n23 = -targetData.readFloat();
	 *      mat.n33 =  targetData.readFloat();
	 *      mat.n43 =  targetData.readFloat();
     *  &#xA0;
	 *      mat.n14 =  targetData.readFloat();
	 *      mat.n24 = -targetData.readFloat();
	 *      mat.n34 =  targetData.readFloat();
	 *      mat.n44 =  targetData.readFloat();
     *  &#xA0;
	 *      // show target object and apply transformation
	 *      showObject(targetID, mat);
	 *    }
	 *  </pre>
	 *
	 *  The 2nd row of the pose matrix is inverted to convert from a right-handed
	 *  coordinate system to a left-handed coordinate system.
	 */
	public function getTrackerResults():ByteArray
	{
		if (! m_alcMemory) return null;
		m_alcMemory.position = m_trackerLib.getTrackerResultPtr();
		return m_alcMemory;
	}

	// ------------------------------------------------------------------------

	/**
	 *  Returns the 2d-tracking results. Call this method after <code>update()</code>
	 *  found one or more targets.
	 *  
	 *  @return The 2d-tracking results are returned as a <code>ByteArray</code> structure
	 *  of the following form:
	 *  <pre>
	 *    reserved:int;        // reserved for later use
	 *    targetID:int;        // unique identifier of the target
	 *  &#xA0;
	 *  &#xA0;                 // corner points of the target in image space
	 *    cornerUL_x:Number;   // upper left corner point
	 *    cornerUL_y:Number;
	 *  &#xA0;
	 *    cornerUR_x:Number;   // upper right corner point
	 *    cornerUR_y:Number;
	 *  &#xA0;
	 *    cornerLR_x:Number;   // lower right corner point
	 *    cornerLR_y:Number;
	 *  &#xA0;
	 *    cornerLL_x:Number;   // lower left corner point
	 *    cornerLL_y:Number;
	 *  </pre>
	 *  This structure is repeated in the <code>ByteArray</code> for every target found.
	 *
	 */
	public function getTrackerResults2D():ByteArray
	{
		if (! m_alcMemory) return null;
		m_alcMemory.position = m_trackerLib.getTrackerResult2DPtr();
		return m_alcMemory;
	}

	// ------------------------------------------------------------------------

	/**
	 *  Sets a button handler that will be invoked if a virtual button that was
	 *  defined with the function <code>addButton()</code> was pressed or released.
	 *  
	 *  @param obj If the button handler is a method of an object, set this to the
	 *  method's object. Otherwise pass <code>null</code>
	 *
	 *  @param handler The callback function that will be invoked whenever a virtual
	 *  button was pressed or released. The function must be of type
	 *  <code>function(uint,&#xA0;uint,&#xA0;Boolean):void</code>.
	 *  <p/>
	 *  As first argument to the callback function the id of the button's target
	 *  will be passed. The second argument is the button's id. The third argument
	 *  is either <code>true</code> (button was pressed) or
	 *  <code>false</code> (button was released).
	 */
	public function setButtonHandler(obj:Object, handler:Function):void
	{
		m_trackerLib.setButtonHandler(obj, handler);
	}

	// ------------------------------------------------------------------------

	/**
	 *  Adds a virtual button to a target. A virtual button is a rectangular area
	 *  on the target that will be checked at runtime for occlusion.
	 *  <p/>
	 *  If this area is covered (e.g. by moving your finger over the button),
	 *  a button press event is generated and the button handler function that
	 *  was defined with <code>setButtonHandler()</code> is called.
	 *  A release event is triggered when the button is uncovered again.
	 *  
	 *  @param targetID The id of the target to add a button for. To find out the id
	 *  of a target image, look at the assignments in the feature-set file.
	 *  
	 *  @param x0 The x-coordinate of the upper-left corner of the button
	 *
	 *  @param y0 The y-coordinate of the upper-left corner of the button
	 *
	 *  @param x1 The x-coordinate of the lower-right corner of the button
	 *
	 *  @param y1 The y-coordinate of the lower-right corner of the button
	 *
	 *  @param minCoverage The percentage of the area that needs to be covered
	 *  to set the button's state to "blocked". This is a float value greater than
	 *  0 (0%) and smaller than 1 (100%).<br/>
	 *  If 0 is passed or the value is omitted, a default coverage value of
	 *  0.7 (70%) is assumed.
	 *
	 *  @param minBlockedFrames Number of frames during an observation period of
	 *  <code>historyLength</code> frames the button has to be in blocked state
	 *  in order to trigger a button press event.<br/>
	 *  If 0 is passed or the value is omitted, a default value of 12 is assumed.
	 *
	 *  @param historyLength Length of the observation period of a button's state.
	 *  The shorter the history, the faster the button will react with a press
	 *  or release event. However, if the history is too short, "false" events
	 *  may occur, resulting in a jitter-like behavior. If the history is to long,
	 *  the events will be very stable, but the button will react with a considerable
	 *  delay. The length of the delay is <code>historyLength/frameRate</code>
	 *  seconds.<br/>
	 *  If 0 is passed or the value is omitted, a default value of 15 is assumed.
	 *
	 *  @return The id of the new button is returned. If the function fails, -1 is returned.
	 */
	public function addButton(targetID:uint, x0:Number, y0:Number, x1:Number, y1:Number,
	                          minCoverage:Number=0,
	                          minBlockedFrames:uint=0, historyLength:uint=0):int
	{
		return (m_trackerLib.addButton(targetID, x0, y0, x1, y1,
		                               minCoverage, minBlockedFrames, historyLength));
	}

	// ------------------------------------------------------------------------

	private function initTracker():void {
		var isOk:Boolean = m_trackerLib.initTracker(m_stage, m_camWidth, m_camHeight,
													m_multiTargets,
													m_camFPS, m_camFile);
		if (!isOk) throw "ERROR: initTracker() failed.";

		// load features
		isOk = m_trackerLib.loadTargets(m_featureSetFile);
		if (!isOk) throw "ERROR: loadTargets() failed.";

		// retrieve the "alchemy memory"
		var ns : Namespace = new Namespace("cmodule.libFlareNFT");
		m_alcMemory   = (ns::gstate).ds;

		// get offset to image buffer
		m_alcImagePointer = m_trackerLib.getImageBufferPtr();

		m_initDoneCB();		// callback function to indicate that init() is finished
	}
	
	// ------------------------------------------------------------------------

	private function fileLoadedCB(url:String, data:Object, errMsg:String=null):void
	{
		var lines:Array;
		var i:int, p:int;
		var file:String, line:String;
		var fileExt:String = ".pgm";

		try
		{
			if (errMsg) throw "ERROR: File \"" + url + "\" load failed: " + errMsg;

			m_CLib.supplyFile(url, ByteArray(data));

			if (url == m_featureSetFile && m_featureSetFile.substr(-4)!=".swf")		// parse feature-set file
			{
				lines = (data.toString()).split("\n");
				for(i = 0; i<lines.length; i++)
				{
					line = lines[i];
					p = line.search("=") + 1;
					if (p <= 1) continue;
					file = trimString(line.substr(p));

					if (line.search(/database\s*=/) == 0)
					{
						// load database files
						m_fileLoader.load(file + ".set"   , m_dataPath);
						m_fileLoader.load(file + "_0.spil", m_dataPath);
						m_fileLoader.load(file + "_1.spil", m_dataPath);
						m_fileLoader.load(file + "_2.spil", m_dataPath);
					}
					else if (line.search(/target-ext\s*=/) == 0)
					{
						fileExt = "." + file;
					}
					else if (line.search(/target\d*-name\s*=/) == 0)
					{
						// flare* needs images to be in PGM format
						// (images in different format need another loader)
						if (fileExt.toLowerCase() == ".pgm")
							m_fileLoader.load(file + fileExt, m_dataPath);
						else
							m_fileLoader.loadImage(file + fileExt, m_dataPath);
					}
				}
				// preloading is finished now
				m_fileLoader.loadEnd();
			}

			if (url == "CAM.INI") m_camFile = "CAM.INI";
				
			// load targets, after all ini-files have been loaded
			if (m_fileLoader.allFilesLoaded())
				initTracker();
		}
		catch (errStr:*)
		{
			if (m_logFunc != null) m_logFunc(0, String(errStr));
		}
	}

	// ------------------------------------------------------------------------

}

// ----------------------------------------------------------------------------

}

import flash.display.Bitmap;
import flash.display.Loader;
import flash.display.LoaderInfo;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.geom.Rectangle;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.system.LoaderContext;
import flash.system.ApplicationDomain;
import flash.utils.ByteArray;

// ----------------------------------------------------------------------------

// helper class to load files into memory

class FilePreloader
{
	private var m_loadCB:Function;
	private var m_ldrArray:Array;
	private var m_filesToLoad:uint;
	private var m_loadEnd:Boolean;
	
	// ------------------------------------------------------------------------
	
	public function FilePreloader(loadCB:Function)
	{
		m_loadCB = loadCB;
		m_ldrArray = new Array();
		m_filesToLoad = 0;
		m_loadEnd = false;
	}

	// ------------------------------------------------------------------------

	public function load(filename:String, path:String):void
	{
		var url:String = path.substr(-1);
		if ((url != "") && (url != "/") && (url != "\\")) path += "/";
		url = path + filename;

		try {
			var loader:URLLoader = new URLLoader();
			m_ldrArray.push([loader, filename]);
	
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorCB);
			loader.addEventListener(IOErrorEvent.IO_ERROR, errorCB);
			loader.addEventListener(Event.COMPLETE, dataCB);
			loader.load(new URLRequest(url));
			m_filesToLoad++;
		}
		catch (err:Error) { onError(filename, err.message); }
	}
	
	// ------------------------------------------------------------------------
	
	public function loadDatasetSWF(filename:String, path:String):void
	{
		var url:String = path.substr(-1);
		if ((url != "") && (url != "/") && (url != "\\")) path += "/";
		url = path + filename;

		try {
			var loader:Loader = new Loader();
			m_ldrArray.push([loader.contentLoaderInfo, filename]);
	
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, errorCB);
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, dataSWFCB);
			loader.load(new URLRequest(url),
			            new LoaderContext(false, ApplicationDomain.currentDomain));
			m_filesToLoad++;
		}
		catch (err:Error) { onError(filename, err.message); }
	}	

	// ------------------------------------------------------------------------

	public function loadImage(filename:String, path:String):void
	{
		var url:String = path.substr(-1);
		if ((url != "") && (url != "/") && (url != "\\")) path += "/";
		url = path + filename;

		try {
			var loader:Loader = new Loader();
			m_ldrArray.push([loader.contentLoaderInfo, filename]);
	
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, errorCB);
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, dataImageCB);
			loader.load(new URLRequest(url),
			            new LoaderContext(false, ApplicationDomain.currentDomain));
			m_filesToLoad++;
		}
		catch (err:Error) { onError(filename, err.message); }
	}

	// ------------------------------------------------------------------------

	public function loadStart():void	{ m_loadEnd = false; m_filesToLoad = 0; }
	public function loadEnd():void		{ m_loadEnd = true;	}

	public function allFilesLoaded():Boolean
	{
		return (m_loadEnd && (m_filesToLoad == 0));
	}

	// ------------------------------------------------------------------------
	
	private function onLoad(url:String, data:Object):void
	{
		m_filesToLoad--;
		if (m_loadCB != null) m_loadCB(url, data);
	}

	// ------------------------------------------------------------------------

	private function onError(url:String, errMsg:String):void
	{
		if (m_loadCB != null) m_loadCB(url, null, errMsg);
	}

	// ------------------------------------------------------------------------
	
	private function errorCB(event:Event):void
	{
		onError(getLoaderURL(event.target), event.type);
	}
	
	// ------------------------------------------------------------------------
	
	private function dataCB(event:Event):void
	{
		var ldr:URLLoader = URLLoader(event.target);
		onLoad(getLoaderURL(ldr), ldr.data);
	}

	// ------------------------------------------------------------------------
	
	private function dataSWFCB(event:Event):void
	{
		
		var co:Object = event.target.content;
		
		var lines:Array;
		var i:int, p:int, imgnr:int=0;
		var file:String, line:String;
		
		lines = (co.ini.toString()).split("\n");
		for(i = 0; i<lines.length; i++)
		{
			line = lines[i];
			p = line.search("=") + 1;
			if (p <= 1) continue;
			file = trimString(line.substr(p));

			if (line.search(/database\s*=/) == 0)
			{
				// load database files
				m_filesToLoad += 4;
				onLoad(file + ".set"   , ByteArray(co.set));
				onLoad(file + "_0.spil", ByteArray(co.spils[0]));
				onLoad(file + "_1.spil", ByteArray(co.spils[1]));
				onLoad(file + "_2.spil", ByteArray(co.spils[2]));
			}
			else if (line.search(/target\d*-name\s*=/) == 0)
			{
				m_filesToLoad ++;
				onLoad(file + ".pgm", ByteArray(co.pages[imgnr]));
				imgnr++;
			}
		}
		
		if ("cam" in co) { m_filesToLoad++; onLoad("CAM.INI" , ByteArray(co.cam)); }
		if (co.lic) { m_filesToLoad++;  onLoad("flareNFT.lic" , ByteArray(co.lic)); }

		var ldr:LoaderInfo = LoaderInfo(event.target);
		onLoad(basename(getLoaderURL(ldr).replace(/[\\]/g, "/")), co.ini);
	}

	// ------------------------------------------------------------------------
	
	private function dataImageCB(event:Event):void
	{
		// make sure we loaded a bitmap and nothing else
		var ldr:LoaderInfo = LoaderInfo(event.target);
		var url:String     = getLoaderURL(ldr);
		if (! (ldr.content is Bitmap))
		{
			onError(url, "unsupported type: " + ldr.contentType);
			return;
		}

		// get the bitmap's pixels as ByteArray and convert it to 8-bit binary PGM format
		var bmp:Bitmap          = Bitmap(ldr.content);
		var rect:Rectangle      = new Rectangle(0, 0, bmp.width, bmp.height);
		var pixelData:ByteArray = bmp.bitmapData.getPixels(rect);
		var numPixels:uint      = (pixelData.length >> 2);

		var pgmData:ByteArray = new ByteArray();
		pgmData.writeUTFBytes("P5\n# flare*\n" + bmp.width + " " + bmp.height + "\n255\n");

		var gray:uint;
		pixelData.position = 0;
		while (numPixels--)
		{
			pixelData.readUnsignedByte();		// skip alpha
			// convert to LUM, green channel counts twice
			gray = ( (pixelData.readUnsignedByte() +
			         (pixelData.readUnsignedByte() << 1) +
			          pixelData.readUnsignedByte()) >> 2 );
			pgmData.writeByte(gray);
		}

		// now replace the extension with .pgm - this is what libFlareNFT loads
		var p:int = url.lastIndexOf(".");
		if (p > 0) url = url.substr(0, p);
		url += ".pgm";
		onLoad(url, pgmData);
	}

	// ------------------------------------------------------------------------
	
	private function getLoaderURL(loader:Object):String
	{
		for (var i:uint = 0; i < m_ldrArray.length; i++)
		{
			if (m_ldrArray[i][0] == loader)
			{
				loader.removeEventListener(IOErrorEvent.IO_ERROR, errorCB);
				if (loader is URLLoader)
				{
					loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, errorCB);
					loader.removeEventListener(Event.COMPLETE, dataCB);
				}
				else loader.removeEventListener(Event.COMPLETE, dataImageCB);

				var url:String = m_ldrArray[i][1];
				m_ldrArray.splice(i, 1);		// removes element at index i
				return url;
			}
		}
		// should never get here
		return "";
	}

	// ------------------------------------------------------------------------
	
}

// ------------------------------------------------------------------------

function trimString(str:String):String
{
	function isWS(character:String):Boolean
	{
		switch (character)
		{
			case " ":
			case "\t":
			case "\r":
			case "\n":
			case "\f":
				return true;

			default:
				return false;
		}
	}		

	var startIndex:int = 0;

	while (isWS(str.charAt(startIndex))) startIndex++;

	var endIndex:int = str.length - 1;
	while (isWS(str.charAt(endIndex))) endIndex--;

	if (endIndex >= startIndex)
		return str.slice(startIndex, endIndex + 1);
	else
		return "";
}

function basename(fn:String):String {
	return (fn.lastIndexOf("/") >= 0) ? fn.substr(fn.lastIndexOf("/") + 1) : fn;
}