#!/bin/sh

# The project must be configured this way
XCODEPROJ_NAME="Framework.xcodeproj"
LIBRARY_TARGET_NAME="Library"
PLATFORMS_FILENAME="platforms"

##
# check params
if [ ! -n "$1" ]; then
	echo "Usage : $0 [path/to/lib/directory]"
	exit -1
fi
if [ ! -d $1 ]; then
	echo "$1 does not exist"
	exit -2
fi

# move to target
OLDWD=`pwd`
cd $1

##
# find Xcode project to compile
PROJECTS=(*.xcodeproj)
if [ ! -d ${XCODEPROJ_NAME} ]; then
	echo "There must be a project named ${XCODEPROJ_NAME} in `pwd`"
	exit -1
fi
PROJECT=${PROJECTS[0]}


## 
# Find platforms to build for this library
if [ -f platforms ]; then
	PLATFORMS=`cat ${PLATFORMS_FILENAME}`; 
else 
	PLATFORMS="macosx iphone"
fi

if [[ "$PLATFORMS" == *macosx* ]]; then SDKS="macosx"; fi
if [[ "$PLATFORMS" == *iphone* ]]; then SDKS="$SDKS iphoneos iphonesimulator"; fi

if [[ "$PLATFORMS" != *iphone* ]] && [[ "$PLATFORMS" != *macosx* ]]; then 
	echo "platforms file in `pwd` must contain only \"macosx\" and \"iphone\""; 
	exit -3
fi
LIBRARY=$(basename $(pwd))

echo "building ${LIBRARY} for platforms : ${PLATFORMS}"

# internal constants
SYMROOT="build"
PUBLIC_HEADERS_FOLDER_PATH="Headers"

# Compile
for SDK in $SDKS
do
	echo " compiling for ${SDK}"
    xcodebuild build\
        -project ${XCODEPROJ_NAME}\
        -configuration Release\
        -target ${LIBRARY_TARGET_NAME}\
    	PRODUCT_NAME=${LIBRARY}\
        SDKROOT=${SDK}\
        PUBLIC_HEADERS_FOLDER_PATH=${PUBLIC_HEADERS_FOLDER_PATH}\
        SYMROOT=${SYMROOT}\
		CONFIGURATION_BUILD_DIR=${SYMROOT}/${LIBRARY}.libraries/${SDK}\
        ARCHS=\$VALID_ARCHS\
		> /tmp/$$.xcodebuild.log # Store log away and display it in case of error
	if [ $? -ne 0 ]
		then
		cat /tmp/$$.xcodebuild.log
		rm /tmp/$$.xcodebuild.log	
		exit 1
	fi
	rm /tmp/$$.xcodebuild.log	
done

# Make frameworks
for PLATFORM in $PLATFORMS
do
	echo " making framework for ${PLATFORM}"
    FRAMEWORK_PATH="${PLATFORM}/${LIBRARY}.framework"
    mkdir -p "${FRAMEWORK_PATH}/Versions/A/Headers"

    ln -sfh "A" "${FRAMEWORK_PATH}/Versions/Current"
    ln -sfh "Versions/Current/Headers" "${FRAMEWORK_PATH}/Headers"
    ln -sfh "Versions/Current/${LIBRARY}" "${FRAMEWORK_PATH}/${LIBRARY}"

    cp -a `find ${SYMROOT}/${LIBRARY}.libraries/${PLATFORM}*/${PUBLIC_HEADERS_FOLDER_PATH}/` "${FRAMEWORK_PATH}/Versions/A/Headers"
    lipo -create `find ${SYMROOT}/${LIBRARY}.libraries/${PLATFORM}*/lib${LIBRARY}.a` -output "${FRAMEWORK_PATH}/Versions/Current/${LIBRARY}"
	echo "  ${FRAMEWORK_PATH}"
done

##
# cleanup
if [ $OLDWD ]; then
	cd $OLDWD
fi
exit 0