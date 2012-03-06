#!/bin/sh

# Move to directory
if [ $1 ]
	then
	if [ -d $1 ]
		then
		OLDWD=`pwd`
		cd $1
	else
		echo "Usage : $0 [path/to/directory]"
		exit -1
	fi
fi

# internal variables
# PLATFORMS="macosx iphoneos iphonesimulator"
# SHORT_PLATFORMS="macosx iphone"
PLATFORMS="iphoneos iphonesimulator"
SHORT_PLATFORMS="iphone"

SYMROOT="build"
PUBLIC_HEADERS_FOLDER_PATH="Headers"

LIBRARY_TARGET_NAME="Library"

# find Xcode projects to compile
PROJECTS="*.xcodeproj"
if [ ! -d $PROJECTS ]
	then
	echo "no Xcode project found in `pwd`"
	exit -1
fi

# For each Xcode project
for PROJECT in $PROJECTS
do
	LIBRARY=${PROJECT%.*}
	echo "building ${LIBRARY}"

    # Compile
    for PLATFORM in $PLATFORMS
    do
		echo " compiling for ${PLATFORM}"
        xcodebuild build\
            -project $PROJECT\
            -configuration Release\
            -target ${LIBRARY_TARGET_NAME}\
        	PRODUCT_NAME=${LIBRARY}\
            SDKROOT=${PLATFORM}\
            PUBLIC_HEADERS_FOLDER_PATH=${PUBLIC_HEADERS_FOLDER_PATH}\
            SYMROOT=${SYMROOT}\
			CONFIGURATION_BUILD_DIR=${SYMROOT}/${LIBRARY}.libraries/${PLATFORM}\
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
    for PLATFORM in $SHORT_PLATFORMS
    do
		echo " making framework for ${PLATFORM}"
        FRAMEWORK_PATH="${SYMROOT}/${PLATFORM}/${LIBRARY}.framework"
        mkdir -p "${FRAMEWORK_PATH}/Versions/A/Headers"

        ln -sfh "A" "${FRAMEWORK_PATH}/Versions/Current"
        ln -sfh "Versions/Current/Headers" "${FRAMEWORK_PATH}/Headers"
        ln -sfh "Versions/Current/${LIBRARY}" "${FRAMEWORK_PATH}/${LIBRARY}"

        cp -a `find ${SYMROOT}/${LIBRARY}.libraries/${PLATFORM}*/${PUBLIC_HEADERS_FOLDER_PATH}/` "${FRAMEWORK_PATH}/Versions/A/Headers"
        lipo -create `find ${SYMROOT}/${LIBRARY}.libraries/${PLATFORM}*/lib${LIBRARY}.a` -output "${FRAMEWORK_PATH}/Versions/Current/${LIBRARY}"
		echo "  ${FRAMEWORK_PATH}"
    done
done

# cleanup
if [ $OLDWD ]
	then
	cd $OLDWD
fi
exit 0