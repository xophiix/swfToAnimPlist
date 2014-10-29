set pwd=%cd
set jarfile=%~dp0/SpriteMapper.jar
workingDir=%1
shift
cd "%workingDir%"
java -Xmx2g -Djava.awt.headless=true -jar "%jarfile%" "$@"
cd "%pwd%"