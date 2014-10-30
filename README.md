SwfToAnimPlist
==============
A gui tool written by AIR to convert swf to cocos2d animation plist.

##requirement
java6 or java7 runtime
see www.java.com

##build
clone the depend repos:
* https://github.com/51systems/as3crypto.git
* https://github.com/xophiix/as3plist 

after clone the repos above, add them to your flash builder workspace.

##contribute
a spritemapper tool is used in my app to perform animation spritesheet generation:
https://github.com/huandu/spritemapper

##tips
* the app always read swf's root scene's first movieclip.
* when convert `foo.swf`, the output files will always be `foo.meta.plist`, `foo.anim.plist`, `foo.packed.png`.
 * `foo.meta.plist` the final spritesheet info for packed frame image.
 * `foo.packed.png` the final image contain all frames.
 * `foo.anim.plist` the animation plist can be used in cocos2d. it contain only one animation named `main`.

###about the `use depend prefix` option
this option is specific for my current project while normal cocos2d usage always use no prefix, so you should uncheck it.
when checked and given the prefix `res/ui`, then the final spritesheet's `textureFileName` should add this prefix to stands for a relative path to my project's resource root, and without .png extesion. e.g. `res/ui/my_texture` insteadof `my_texture.png`. so does the `spritesheets` array item in animation plist, e.g. `res/ui/my_spritesheet` instead of `my_spritesheet.plist`.

##TODO
* convert png sequences directly
* combine multiple swf into one file, assign animation name respectly
