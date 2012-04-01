/*

SimpleModel.as -- A simple model (static meshes and diffuse textures), loaded
                  from .dae, .3ds or .a3d for Alternativa3D.

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
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.Resource;
	import alternativa.engine3d.loaders.Parser3DS;
	import alternativa.engine3d.loaders.ParserA3D;
	import alternativa.engine3d.loaders.ParserCollada;
	import alternativa.engine3d.loaders.ParserMaterial;
	import alternativa.engine3d.loaders.TexturesLoader;
	import alternativa.engine3d.materials.TextureMaterial;
	import alternativa.engine3d.objects.Mesh;
	import alternativa.engine3d.objects.Surface;
	import alternativa.engine3d.resources.ExternalTextureResource;
	import alternativa.engine3d.resources.Geometry;
	
	import flash.display3D.Context3D;
	import flash.events.Event;
	import flash.geom.Matrix3D;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	
	
	public class SimpleModel extends Object3D
	{
		public static const FORMAT_COLLADA:String = ".dae";
		public static const FORMAT_3DS:String = ".3ds";
		public static const FORMAT_A3D:String = ".a3d";
		
		private var context3D_:Context3D;
		private var folder_:String;
		private var format_:String;
		private var offsetMatrix_:Matrix3D;
		
		
		public function SimpleModel
		(
			context3D:Context3D,
			folder:String,
			file:String,
			offsetMatrix:Matrix3D = null,
			format:String = null
		)
		{
			super();
			
			context3D_ = context3D;
			folder_ = folder;
			format_ = format ? format : file.slice(-4).toLowerCase();
			offsetMatrix_ = offsetMatrix;
			
			var loaderCollada:URLLoader = new URLLoader();
			switch(format_)
			{
				case FORMAT_COLLADA:
					loaderCollada.dataFormat = URLLoaderDataFormat.TEXT;
					break;
				case FORMAT_3DS:
				case FORMAT_A3D:
					loaderCollada.dataFormat = URLLoaderDataFormat.BINARY;
					break;
				default:
					trace
					(
						"SimpleModel: Unable to infer file format from extension of \"" + file
						+ "\". Recognized extensions are .dae, .3ds and .a3d."
					);
					break;
			}
			loaderCollada.load(new URLRequest(folder + "/" + file));
			loaderCollada.addEventListener(Event.COMPLETE, onLoadComplete);
		}
		
		
		private function onLoadComplete(event:Event):void
		{
			// Parse the file.
			var objects:Vector.<Object3D>;
			switch(format_)
			{
				case FORMAT_COLLADA:
					var parserCollada:ParserCollada = new ParserCollada();
					parserCollada.parse(XML((event.target as URLLoader).data), folder_ + "/", true);
					objects = parserCollada.objects;
					break;
				case FORMAT_3DS:
					var parser3DS:Parser3DS = new Parser3DS();
					parser3DS.parse((event.target as URLLoader).data);
					objects = parser3DS.objects;
					break;
				case FORMAT_A3D:
					var parserA3D:ParserA3D = new ParserA3D();
					parserA3D.parse((event.target as URLLoader).data);
					objects = parserA3D.objects;
					break;
			}
			
			// Iterate over all the parsed nodes.
			for each(var object:Object3D in objects)
			{
				if(!(object is Mesh))
				{
					// Skip the non-mesh node.
					continue;
				}
				var mesh:Mesh = object as Mesh;
				
				if(offsetMatrix_)
				{
					// Apply the offset to the mesh.
					mesh.matrix = offsetMatrix_;
				}
				
				// Add the mesh to this 3D object.
				addChild(mesh);
				
				// Upload the mesh's geometry in the graphics context.
				for each(var resource:Resource in mesh.getResources(false, Geometry))
				{
					resource.upload(context3D_);
				}
				
				// Determine which textures need to be loaded.
				var textures:Vector.<ExternalTextureResource> = new Vector.<ExternalTextureResource>();
				for (var i:int = 0; i < mesh.numSurfaces; i++)
				{
					var surface:Surface = mesh.getSurface(i);
					var material:ParserMaterial = surface.material as ParserMaterial;
					if (material != null)
					{
						var diffuse:ExternalTextureResource = material.textures["diffuse"];
						if (diffuse != null)
						{
							switch(format_)
							{
								case FORMAT_3DS:
								case FORMAT_A3D:
									diffuse.url = folder_ + "/" + diffuse.url;
									break;
							}
							textures.push(diffuse);
							surface.material = new TextureMaterial(diffuse);
						}
					}
				}
				
				// Load the textures.
				var texturesLoader:TexturesLoader = new TexturesLoader(context3D_);
				texturesLoader.loadResources(textures);
			}
		}
	}
}