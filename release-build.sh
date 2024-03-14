#!/bin/bash

buildRequiredApps=( "java" "git" "mvn" "ant" "xmlstarlet" )

for app in "${buildRequiredApps[@]}"; do :
   if ! [ -x "$(command -v ${app})" ]; then
     echo "Error: ${app} is not installed." >&2
     exit 1
   fi
done

function showUsage
{
  echo -e "\nThis script is used to build a release for the current branch"
  echo
}

if [ "$1" = "-h" ]
then
	showUsage
	exit
fi

projectVersion=`xmlstarlet sel -t -m "/_:project/_:version" -v . -n pom.xml`
subVersion=`cut -d "-" -f 2 <<< $projectVersion`
mainVersion=`cut -d "-" -f 1 <<< $projectVersion`
mainVersionMajor=`cut -d "." -f 1 <<< $mainVersion`
mainVersionMinor=`cut -d "." -f 2 <<< $mainVersion`
mainVersionSub=`cut -d "." -f 3 <<< $mainVersion`

gitBranch=`git branch --show-current`

nextVersionNumber="${mainVersionMajor}.${mainVersionMinor}.$((mainVersionSub+1))"
previousVersionNumber="${mainVersionMajor}.${mainVersionMinor}.$((mainVersionSub-1))"

from=origin
frombranch=origin/${gitBranch}
series=${mainVersionMajor}.${mainVersionMinor}
versionbranch=${gitBranch}
version=${projectVersion}
minorversion=0
release=latest
newversion=${mainVersion}-$minorversion
currentversion=${projectVersion}
previousversion=${previousVersionNumber}
nextversion=${nextVersionNumber}-SNAPSHOT

echo "Creating release for version ${newversion} (from ${currentversion}). Next version will be ${nextversion}. Git branch ${gitBranch}."
read -p "Press enter to continue"

# TODO: Transifex update
# TODO: Changelog

# Update version number (in pom.xml, installer config and SQL)
./update-version.sh $currentversion $newversion

# Generate list of changes
cat <<EOF > docs/changes/changes$newversion.txt
================================================================================
===
=== GeoNetwork $version: List of changes
===
================================================================================
EOF
git log --pretty='format:- %s' $previousversion... >> docs/changes/changes$newversion.txt

# Then commit the new version
git add .
git commit -m "Update version to $newversion"
git tag -a $version -m "Tag for $version release"

# Build the new release
mvn clean install -DskipTests -Pwar -Pwro4j-prebuild-cache

(cd datastorages && mvn clean install -Drelease -DskipTests)


# Download Jetty and create the installer
(cd release && mvn clean install -Pjetty-download && ant)

# Set version number to SNAPSHOT
./update-version.sh $newversion $nextversion

git add .
git commit -m "Update version to $nextversion"


rm release/target/GeoNetwork-$version/geonetwork-bundle-$newversion.zip.MD5
if [[ ${OSTYPE:0:6} == 'darwin' ]]; then
  md5 -r web/target/geonetwork.war > web/target/geonetwork.war.md5
  md5 -r release/target/GeoNetwork-$newversion/geonetwork-bundle-$newversion.zip > release/target/GeoNetwork-$newversion/geonetwork-bundle-$newversion.zip.md5
else
  (cd web/target && md5sum geonetwork.war > geonetwork.war.md5)
  (cd release/target/GeoNetwork-$version && md5sum geonetwork-bundle-$newversion.zip > geonetwork-bundle-$newversion.zip.md5)
fi
