#!/usr/bin/perl -wT

#
# Modification History
#
# 2003-January-6   Jason Rohrer
# Created.
#
# 2003-January-7   Jason Rohrer
# Updated to test new features.
#


use lib '.';

use strict;


use tokenWord::common;
use tokenWord::chunkManager;
use tokenWord::documentManager;
use tokenWord::userManager;


print "test\n";

setupDataDirectory();

    
    # use regexp to untaint username
    #my ( $safeUsername ) = 
    #    ( $username =~ /(\w+)$/ );
    

tokenWord::userManager::addUser( "jj55", "testPass", "15" );
my $chunkID = tokenWord::chunkManager::addChunk( "jj55", 
                                                 "This is a test chunk." );

my $region = 
  tokenWord::chunkManager::getRegion( "jj55", $chunkID, 10, 4 );
print "chunk region = $region\n";

my $docString = "<jj55, $chunkID, 0, 5>\n<jj55, $chunkID, 10, 4>";
my $docID = 
  tokenWord::documentManager::addDocument( "jj55", $docString );


my $fullDocText =
  tokenWord::documentManager::renderDocumentText( "jj55", $docID );

print "Full document text = \n$fullDocText\n";

$region = 
  tokenWord::documentManager::getRegionText( "jj55", $docID, 2, 2 );
print "document region = $region\n";


sub setupDataDirectory {
    if( not -e "$dataDirectory" ) {
        
        mkdir( "$dataDirectory", oct( "0777" ) );
        mkdir( "$dataDirectory/users", oct( "0777" ) );
    }
}
