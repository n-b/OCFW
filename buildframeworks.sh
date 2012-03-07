#!/bin/sh
set -e

# The project must be configured this way
XCODEPROJ_NAME="Framework.xcodeproj"
LIBRARY_TARGET_NAME="Library"
RESOURCES_TARGET_NAME="Resources"
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

##
# options
OUTDIR=${OUTDIR-`pwd`/Frameworks}
echo "will create frameworks in ${OUTDIR}"

##
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
# check that the project as a "Resources" target
if [[ `xcodebuild -list ${XCODEPROJ_NAME}` == *${RESOURCES_TARGET_NAME}* ]]; then COPY_RESOURCES=true; fi


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
LOGFILE=/tmp/$$.xcodebuild.log

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
		CONFIGURATION_BUILD_DIR=${SYMROOT}/${LIBRARY}/${SDK}\
        ARCHS=\$VALID_ARCHS\
			> ${LOGFILE}
	if [ $? -ne 0 ]; then cat ${LOGFILE}; exit 1; fi
	
	# copy resources, if any
	if [ $COPY_RESOURCES ]; then
		echo " copying resources for ${SDK}"
		xcodebuild build\
	        -project ${XCODEPROJ_NAME}\
	        -configuration Release\
			-target ${RESOURCES_TARGET_NAME}\
			PRODUCT_NAME=${RESOURCES_TARGET_NAME}\
	        SDKROOT=${SDK}\
			WRAPPER_EXTENSION=${RESOURCES_TARGET_NAME}\
	        SYMROOT=${SYMROOT}\
			CONFIGURATION_BUILD_DIR=${SYMROOT}/${LIBRARY}/${SDK}\
				> ${LOGFILE}
		if [ $? -ne 0 ]; then cat ${LOGFILE}; exit 1; fi
	fi
done

# Make frameworks
for PLATFORM in $PLATFORMS
do
	echo " making framework for ${PLATFORM}"
    FRAMEWORK_PATH="${OUTDIR}/${PLATFORM}/${LIBRARY}.framework"

	# create framework structure structure
    mkdir -p "${FRAMEWORK_PATH}/Versions/A/Headers" "${FRAMEWORK_PATH}/Versions/A/Resources"
    ln -sfh "A" "${FRAMEWORK_PATH}/Versions/Current"
    ln -sfh "Versions/Current/Headers" "${FRAMEWORK_PATH}/Headers"
    ln -sfh "Versions/Current/Resources" "${FRAMEWORK_PATH}/Resources"
    ln -sfh "Versions/Current/${LIBRARY}" "${FRAMEWORK_PATH}/${LIBRARY}"

	# merge all corresponding binaries
    lipo -create `find ${SYMROOT}/${LIBRARY}/${PLATFORM}*/lib${LIBRARY}.a` -output "${FRAMEWORK_PATH}/Versions/Current/${LIBRARY}"

	# copy headers
    cp -a `find ${SYMROOT}/${LIBRARY}/${PLATFORM}*/${PUBLIC_HEADERS_FOLDER_PATH}/` "${FRAMEWORK_PATH}/Versions/A/Headers"
	
	# copy resources
	if [ $COPY_RESOURCES ]; then
		cp -a `find ${SYMROOT}/${LIBRARY}/${PLATFORM}*/${RESOURCES_TARGET_NAME}.${RESOURCES_TARGET_NAME}/` "${FRAMEWORK_PATH}/Versions/A/Resources"
	fi

	echo "  ${FRAMEWORK_PATH}"
done

##
# cleanup
if [ $OLDWD ]; then
	cd $OLDWD
fi
exit 0