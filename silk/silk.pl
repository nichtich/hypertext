#!/usr/bin/perl -wT

#
# Modification History
#
# 2004-March-16   Jason Rohrer
# Created.
#
# 2004-March-17   Jason Rohrer
# Added support for external links.
# Added password access.
# Made all quick ref tag searches case-insensitive.
#
# 2004-April-4   Jason Rohrer
# Added locking to protect file updates.
# Added a quick ref tag map that is passed as a hidden variable along
# with a node update to ensure that tag mapping is consistent when
# a node is being edited by multiple users.
# Added hot link flags for each node in current node's link list.
# Added a quick-hot-link checkbox on the edit node/link screens.
#
# 2004-April-5   Jason Rohrer
# Added a read-only mode.
#
# 2004-April-6   Jason Rohrer
# Added support for profiling.
# Added a profiler-suggested optimization.
# Optimized readFileValue to slurp entire file.
# Optimized getNodeTitle to only read the first line of the file.
#
# 2004-April-8   Jason Rohrer
# Added support for getting a backup tarball.
# Added support for restoring from a backup tarball.
# Fixed some helper-app path bugs.  Made compatible with older CGI.pm
#
# 2004-April-9   Jason Rohrer
# Made tarball processing code cleaner.
# Added an ever-present link to the start node.
# Removed unneeded temp directory setting.
# Removed use of Time:HiRes to reduce dependencies.
# Removed settings for SmallProf.
# Changed settings to match SourceForge silk sandbox setup.
#
# 2004-April-11   Jason Rohrer
# Made user options cleaner.
# Made quickref tags color.  Added editing instructions.
#
# 2004-April-12   Jason Rohrer
# Added support for inline title links.
# Changed all quick ref tags to lower case.
# Fixed bugs in title link creation and removal.
#
# 2004-April-17   Jason Rohrer
# Changed to get the script URL from the CGI interface by default.
#
# 2004-April-23   Jason Rohrer
# Fixed a few undefined variable warnings.
# Fixed some wording.
# Changed login form to POST so that password isn't visible in URL field.
# Improved security of password hash file.
# Added a version string.
#
# 2004-June-11   Jason Rohrer
# Fixed a read-only login bug (if no password hash exists) pointed out 
# by Sebastien L.
#
# 2004-December-7   Jason Rohrer
# Changed to use new location of MD5 module.
#
# 2005-September-25   Jason Rohrer
# Changed to leave user linebreaks in file and only process them for display.
# Changed so that login expires in 24 hours instead of 1 hour.
#

my $silkVersion = "0.1.?";



# user options can be customized to a specific system setup
# options are listed here, but set below, after BEGIN {
my $dataDirectory;
my $dataDirectoryName;
my $scriptURL;
my $requirePassword;
my $safePasswordHashLocation;
my $allowReadOnlyAccessWithoutPassword;
my $allowTarballBackupOperations;
my $errorLogPath;


BEGIN {
    
    #### USER OPTIONS START HERE ####

    # you probably need to set the following four options for your system

    # where silk will store its data files.
    # must be writable to the process that runs CGI scripts on your web server
    # you should also edit the $dataDirectory variable for the error log below
    $dataDirectory = "../cgi-data/silk";

    # the name of the data directory.
    # in other words, the last step in the data directory path
    $dataDirectoryName = "silk";
    
    # location of the error log
    # this script must have permissions to create the error log
    $errorLogPath = "../cgi-data/silk_errors.log";

    # the external URL for the silk script
    # leave blank to get the script's URL from the CGI interface
    # (should leave blank for most setups)
    $scriptURL = "";
    

    # the default values set below will work for you if you are running
    # a public silk web


    # set to 1 to require password, or 0 to allow public access
    $requirePassword = 0;

    # If a password is required, the password will be requested and set the 
    #   first time the silk script is run.  The MD5 hash of the password is 
    #   stored in the "password.md5" file in the data directory.
    # To reset the password (so that the script asks for it again),
    #   delete the password.md5 file.
    # For best security, manually make password.md5 read-only after it has been
    #   created by the script (especially if you are using a shared web server
    #   that runs CGI scripts as "nobody").
    # Depending on your system configuration, you may also need to copy
    #   the password.md5 file into a different, read-only directory to prevent
    #   other users from deleting password.md5 and resetting your password.
    #
    # WARNING:
    # For your silk web to be secure, you MUST make sure that only you can
    #   edit/delete your password.md5 file.  If your web server can delete
    #   this file, your file can be deleted by other users running
    #   web scripts on your server (in a shared server setting).
    
    # a different, read-only location for the password hash file.
    # After you log into your silk web the first time, you can copy the
    # script-created password.md5 file here for extra security.
    #
    # If password.md5 exists in this "safe" location, it will override
    # the password.md5 file in the data directory.
    $safePasswordHashLocation = "../password.md5";

    # set to 1 to allow non-authenticated (no password) read-only access
    # (only applies if $requirePassword is set to 1)
    $allowReadOnlyAccessWithoutPassword = 0;

    # set to 1 to allow backup/restore from tarball
    # should probably be disabled for public silk webs 
    $allowTarballBackupOperations = 0;

    # set to include necessary paths for finding tar, gzip, and rm
    # we cannot use the default PATH because taint checking forbids it
    $ENV{ 'PATH' } = "/bin:/usr/bin:/usr/local/bin";



    # end of customizable settings


    #### NO USER OPTIONS BELOW HERE ####




    # setup a local error log
    # we use a BEGIN block for all of these settings so that the error log
    # can catch compilation errors (BEGIN blocks are executed at compile time)
    # the settings are inside the BEGIN block too so that the $errorLogPath
    # can be one of the settings (better to have all settings inside the same
    # block, for consistency)
    use CGI::Carp qw( carpout );
    open( LOG, ">>$errorLogPath" ) or
        die( "Unable to open $errorLogPath: $!\n" );
    carpout( LOG );
}





use strict;
use CGI;                # Object-Oriented version of CGI
use Digest::MD5;



# allow group to write to our data files
umask( oct( "02" ) );


setupDataDirectory();



# map for quick-reference link tags

# we assume, in the code below, that there are at least 3 entries in
# @nodeLinkQuickReferenceTagMap
my @nodeLinkQuickReferenceTagMap = 
    ( "c", "d", "e", "f", "g", "h", "j", "k", "l", "m", "n" );
my @hotLinkQuickReferenceTagMap = 
    ( "o", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" );



# start processing the inbound CGI query
my $cgiQuery = CGI->new();


# if we don't have a script URL set
if( $scriptURL eq "" ) {    
    
    # default to getting the URL from the query
    $scriptURL = $cgiQuery->url();
}


# always set the Pragma: no-cache directive
# this feature seems to be undocumented...
$cgiQuery->cache( 1 );


my $action = $cgiQuery->param( "action" ) || '';



# if required:
# handle retrieving the user's password, checking it, and storing
# it in a cookie

# get the password cookie, if it exists
my $passwordCookie = $cgiQuery->cookie( "password" ) || '';

my $password = "";
my $passwordCorrect = 0;
my $readOnlyMode = 0;

my $passwordHashLocation = "$dataDirectory/password.md5";

# use the safe password hash if it exists
if( -e $safePasswordHashLocation ) {
    $passwordHashLocation = $safePasswordHashLocation;
}


my $passwordHashExists = -e $passwordHashLocation;

if( $requirePassword ) {
    if( $passwordCookie ne "" ) {
        $password = $passwordCookie;
    }
    elsif( $action eq "login" ) {
        $password = $cgiQuery->param( "password" ) || '';
    }

    # check if read only mode is requested
    if( $password eq "readOnly" ) {
        if( $allowReadOnlyAccessWithoutPassword ) {
            $readOnlyMode = 1;
            $passwordCorrect = 1;
        }
    }
    elsif( $password ne "" ) {
        # check password

        my $md5 = new Digest::MD5;
        $md5->add( $password ); 
        my $passwordHash = $md5->hexdigest();

        if( $passwordHashExists ) {
            # check password against hash
            
            my $truePasswordHash = 
                readFileValue( $passwordHashLocation );
            
            if( $truePasswordHash eq $passwordHash ) {
                $passwordCorrect = 1;
            }
        }
        else {
            # user logging in for first time
            
            # save a hash of password
            writeFile( "$dataDirectory/password.md5", $passwordHash );
            
            $passwordHashExists = 1;
        
            # correct by default since it is new
            $passwordCorrect = 1;
        }
    }
}


# set the password cookie if we have a correct password
# and generate the HTTP header

# used below
my $tarballContentDisposition = "attachment; filename=\"silk_backup.tar.gz\"";

if( $requirePassword and $passwordCorrect ) {
    my $cookieToSet;
    
    if( $action eq "logout" ) {
        $cookieToSet = $cgiQuery->cookie( -name=>"password",
                                          -value=>"" );
        $passwordCorrect = 0;
    }
    else {
        $cookieToSet = $cgiQuery->cookie( -name=>"password",
                                          -value=>"$password",
                                          -expires=>"+24h" );
    }

    if( $action eq "getDataTarball" ) {
        print $cgiQuery->header( 
                           -type=>'application-x/gzip',
                           -expires=>'now',
                           -Cache_control=>'no-cache',
                           -Content_Disposition=>"$tarballContentDisposition",
                           -cookie=>[ $cookieToSet ] );
    }
    else {
        print $cgiQuery->header( -type=>'text/html',
                                 -expires=>'now',
                                 -Cache_control=>'no-cache',
                                 -cookie=>[ $cookieToSet ] );
    }
}
elsif( not $requirePassword
       or $allowReadOnlyAccessWithoutPassword ) {
    # password not required or
    # read only access allowed

    # allow tarball fetching

    if( $action eq "getDataTarball" ) {
        print $cgiQuery->header( 
                          -type=>'application-x/gzip', 
                          -expires=>'now',
                          -Cache_control=>'no-cache',
                          -Content_Disposition=>"$tarballContentDisposition" );
    }
    else {
        print $cgiQuery->header( -type=>'text/html', 
                                 -expires=>'now',
                                 -Cache_control=>'no-cache' );
    }
}
else {
    # password required, but not correct
    print $cgiQuery->header( -type=>'text/html', 
                             -expires=>'now',
                             -Cache_control=>'no-cache' );
}




# handle various states and user actions

if( $requirePassword and
    ( ( not $passwordHashExists and $action ne "login" and not $readOnlyMode )
      or ( $passwordHashExists and not $passwordCorrect ) ) ) {
    
    # show the login form

    printPageHeader( "login" );

    print "<CENTER>\n";
    if( not $passwordHashExists ) {
        print "first login -- enter a new password<BR><BR>\n";
    }
    print "<FORM ACTION=\"$scriptURL\" METHOD=POST>\n";

    print "<INPUT TYPE=\"hidden\" " . 
        "NAME=\"action\" VALUE=\"login\">\n";
    
    print "password: <INPUT TYPE=\"password\" MAXLENGTH=256 ".
          "SIZE=20 NAME=\"password\" VALUE=\"\">";
    print "<INPUT TYPE=submit VALUE=\"login\" NAME=\"buttonLogin\">\n";
    print "</FORM>\n";
    
    if( $allowReadOnlyAccessWithoutPassword ) {
        print "<BR><A HREF=\"$scriptURL?action=login&password=readOnly\">".
              "access in read-only mode</A>\n";
    }
    print "</CENTER>";

    printPageFooter();
}
elsif( $allowTarballBackupOperations and $action eq "getDataTarball" ) {

    # open a pipe from the tarball creator 
    open( CREATE_TARBALL_PIPE, 
          "cd $dataDirectory/..; tar cf - $dataDirectoryName | ".
          "gzip -f |" );

    while( <CREATE_TARBALL_PIPE> ) {
        print "$_";
    }
    close( CREATE_TARBALL_PIPE );
}
elsif( $allowTarballBackupOperations and 
       not $readOnlyMode and 
       $action eq "restoreFromDataTarball" ) {

    # $tarballContents is a file handle

    # using upload() instead of param() is safer (deals with errors in a better
    # way), but requires CGI.pm v2.47
    # my $tarballContents = $cgiQuery->upload( "tarball" );
    my $tarballContents = $cgiQuery->param( "tarball" );

    # clear the data directory
    `rm -rf $dataDirectory/*`;

    # open a pipe to the tarball extractor
    open( EXTRACT_TARBALL_PIPE, "| gzip -dcf | tar x -C $dataDirectory/.." ) 
        or die "Cannot start gzip/tar pipe process: $!\n";
    
    # print the tarball to the pipe
    while( <$tarballContents> ) {
        print EXTRACT_TARBALL_PIPE $_;
    }

    close( EXTRACT_TARBALL_PIPE );
    
    printStartNode();
}
elsif( $action eq "showNode" 
       or $action eq "login"
       or $action eq ""
       or $readOnlyMode
       or $action eq "showStartNode" ) {
    # only allow the showNode action in read-only mode
    
    my $nodeID = $cgiQuery->param( "nodeID" );

    if( not defined( $nodeID ) ) {
        $nodeID = "";
    }
    else {
        # untaint
        # may have x-prefix for an external link ID
        ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
    }

    if( $nodeID eq "" 
        or $action eq "showStartNode" ) {
        
        printStartNode();
    }
    else {
        printNode( $nodeID );
    }
}
elsif( not $readOnlyMode and 
       $action eq "showRestoreForm" ) {
    
    # show the tarball selection form

    printPageHeader( "restore from tarball" );

    print "<CENTER>\n";

    print "<FORM METHOD=POST ACTION=\"$scriptURL\" ".
          "ENCTYPE=\"multipart/form-data\">\n";

    print "<INPUT TYPE=\"hidden\" " . 
          "NAME=\"action\" VALUE=\"restoreFromDataTarball\">\n";
    
    print 
        "tarball file: <INPUT TYPE=\"file\" NAME=\"tarball\" VALUE=\"\"><BR>";
    print "<INPUT TYPE=submit VALUE=\"restore\" NAME=\"buttonRestore\">\n";
    print "</FORM>\n";
    
    print "</CENTER>";

    printPageFooter();
}
elsif( $action eq "makeLink" ) {
    my $firstNodeID = $cgiQuery->param( "firstNodeID" );
    my $secondNodeID = $cgiQuery->param( "secondNodeID" );

    #untaint
    # may have x-prefix for an external link ID
    ( $firstNodeID ) = ( $firstNodeID =~ /(x?\d+)/ );
    ( $secondNodeID ) = ( $secondNodeID =~ /(x?\d+)/ );
    
    
    if( $firstNodeID ne "" and $secondNodeID ne "" ) {
        makeLink( $firstNodeID, $secondNodeID );
    }

    printNode( $firstNodeID );
}
elsif( $action eq "removeLinks" ) {
    my $firstNodeID = $cgiQuery->param( "firstNodeID" );
    
    #untaint
    ( $firstNodeID ) = ( $firstNodeID =~ /(x?\d+)/ );

    if( $firstNodeID ne "" ) {
        my @idsToRemove = $cgiQuery->param( "secondNodeID" );
        
        foreach my $secondNodeID ( @idsToRemove ) {
            # untaint
            ( $secondNodeID ) = ( $secondNodeID =~ /(x?\d+)/ );
    
    
            if( $secondNodeID ne "" ) {
                removeLink( $firstNodeID, $secondNodeID );
            }
        }
    }

    printNode( $firstNodeID );
}
elsif( $action eq "addToHotLinks" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );
    
    # untaint
    # may be of form  139   or of form   x139  
    ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
    
    my $showNodeID = $cgiQuery->param( "showNodeID" );
    
    # untaint
    # may be of form  139   or of form   x139  
    ( $showNodeID ) = ( $showNodeID =~ /(x?\d+)/ );

    addToHotLinks( $nodeID );

    printNode( $showNodeID );
}
elsif( $action eq "removeHotLinks" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );
    
    #untaint
    ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
    

    # idToRemove parameter might occur multiple times, once for
    # each node that is flagged for removal from the hot links list.
    my @idsToRemove = $cgiQuery->param( "idToRemove" );

    
    # lock to protect our file update    
    open( LOCK_FILE, "$dataDirectory/lock" ) or die;
    flock( LOCK_FILE, 2 ) or die;


    my $oldLinksText = readFileValue( "$dataDirectory/hot.links" );
    
    # if some ids are listed for removal
    # and if our hot links list is not empty already
    if( scalar( @idsToRemove ) > 0 and
        $oldLinksText ne "" ) {
        
        # split by lines
        my @oldLinkIDs = split( /\n/, $oldLinksText );

        # build a new list
        my @newLinkIDs = ();

        foreach my $oldID ( @oldLinkIDs ) {
            
            my $removed = 0;
            foreach my $id ( @idsToRemove ) {
                if( $id eq $oldID ) {
                    $removed = 1;
                }
                
            }
            
            if( not $removed ) {
                push( @newLinkIDs, "$oldID\n" );
            }
            # else drop the ID
        }
        
        

        my $newLinkText = join( "", @newLinkIDs );

        writeFile( "$dataDirectory/hot.links", $newLinkText );
    }

    
    close( LOCK_FILE );


    printNode( $nodeID );
}
elsif( $action eq "updateNode" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );
    
    #untaint
    ( $nodeID ) = ( $nodeID =~ /(\d+)/ );

    my $nodeText = $cgiQuery->param( "nodeText" ) || '';

    # fix "other" newline styles.
    
    # replace \r\n (DOS) with \n
    $nodeText =~ s/\r\n/\n/g;
    # replace \r (Mac) with \n
    $nodeText =~ s/\r/\n/g;
            
    
    
    # replace all quck-ref links with direct node links
    # add to our node link list if needed

    # use the quick ref tag map that is included in the update
    my $quickRefMapString = $cgiQuery->param( "quickRefMap" ) || '';

    # split based on ;
    # this gives us a flat array of key,value pairs
    my @quickRefMapParts = split( /[;]/, $quickRefMapString );
    

    my @linkIDs = getNodeLinks( $nodeID );

    foreach my $mapEntry ( @quickRefMapParts ) {
        
        ( my $tag, my $linkID ) = split( /,/ , $mapEntry );
        
        #untaint
        # may be of form  139   or of form   x139  
        ( $linkID ) = ( $linkID =~ /(x?\d+)/ );

        if( $nodeText =~ m/<\s*$tag\s*(\s+t)?>/i ) {
            # text contains a link to this tag
            
            # make sure that this node is on our link list
            makeLink( $nodeID, $linkID );

            # replace quick ref tags (<d></d>) with direct links (<13></13>)
            # allow whitespace in tag (\s*)
            $nodeText =~
                s/<\s*$tag\s*>/<$linkID>/gi;
            $nodeText =~
                s/<\s*\/\s*$tag\s*>/<\/$linkID>/gi;
            
            # replaced inlined quick ref title tags (<d t>) with inlined 
            # direct title tags (<13 t>)
            # allow extra whitespace in tag (\s* and \s+)
            $nodeText =~
                s/<\s*$tag\s+t\s*>/<$linkID t>/gi;

            
        }        
    }
   
    writeFile( "$dataDirectory/nodes/$nodeID.txt", $nodeText );
    
    my $autoAddToHotLinks = $cgiQuery->param( "autoAddToHotLinks" ) || '';
    
    if( $autoAddToHotLinks eq "1" ) {
        addToHotLinks( "$nodeID" );
    }
    
    if( not -e "$dataDirectory/startNode" ) {
        # this new node defaults as our start node
        writeFile( "$dataDirectory/startNode", $nodeID );
    }

    printNode( $nodeID );
}
elsif( $action eq "updateExternalLink" ) {
    my $linkID = $cgiQuery->param( "linkID" );
    
    #untaint
    ( $linkID ) = ( $linkID =~ /(\d+)/ );

    my $linkTitle = $cgiQuery->param( "linkTitle" ) || '';
    my $linkURL = $cgiQuery->param( "linkURL" ) || '';    

    my $autoAddToHotLinks = $cgiQuery->param( "autoAddToHotLinks" ) || '';    

    
    # lock around updates    
    open( LOCK_FILE, "$dataDirectory/lock" ) or die;
    flock( LOCK_FILE, 2 ) or die;
    
    writeFile( "$dataDirectory/externalLinks/$linkID.title", $linkTitle );
    writeFile( "$dataDirectory/externalLinks/$linkID.url", $linkURL );

    close( LOCK_FILE );
    
    if( $autoAddToHotLinks eq "1" ) {
        addToHotLinks( "x$linkID" );
    }
    
    if( not -e "$dataDirectory/startNode" ) {
        # this new node defaults as our start node
        writeFile( "$dataDirectory/startNode", "x$linkID" );
    }


    printNode( "x$linkID" );    
}
elsif( $action eq "editExternalLink" or 
       $action eq "newExternalLink" ) {
    my $linkID = "";
    my $linkTitle = "";
    my $linkURL = "";

    if( $action eq "editExternalLink" ) {
        $linkID = $cgiQuery->param( "linkID" );

        #untaint
        ( $linkID ) = ( $linkID =~ /(\d+)/ );

        $linkTitle = getNodeTitle( "x$linkID" );
        $linkURL = getExternalLinkURL( $linkID );
    }
    
    if( $linkID eq "" ) {
        # lock to protect our file update    
        open( LOCK_FILE, "$dataDirectory/lock" ) or die;
        flock( LOCK_FILE, 2 ) or die;

        $linkID = readFileValue( "$dataDirectory/nextExternalLinkID" );
        
        #untaint
        ( $linkID ) = ( $linkID =~ /(\d+)/ );

        writeFile( "$dataDirectory/nextExternalLinkID", $linkID + 1 );
        
        close( LOCK_FILE );

        writeFile( "$dataDirectory/externalLinks/$linkID.url", $linkURL );
        
        writeFile( "$dataDirectory/externalLinks/$linkID.links", "" );
        
        $linkTitle = "";
        $linkURL = "http://";
    }

    printPageHeader( "edit external link" );
    
    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
    
    print "<TR><TD VALIGN=TOP ALIGN=CENTER WIDTH=75%>\n";
    

    print "<BR>\n<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=90%>\n";
    print "<TR><TD>\n";

    print "<FONT SIZE=5>edit external link</FONT><BR>\n";

    print "<FORM METHOD=POST ACTION=\"$scriptURL\">\n";

    print "<INPUT TYPE=\"hidden\" " . 
        "NAME=\"action\" VALUE=\"updateExternalLink\">\n";
    print "<INPUT TYPE=\"hidden\" NAME=\"linkID\" VALUE=\"$linkID\">\n";

    
    print "<TABLE BORDER=0>\n";
    print "<TR><TD>title:</TD><TD COLSPAN=2>".
          "<INPUT TYPE=\"text\" MAXLENGTH=256 ".
          "SIZE=60 NAME=\"linkTitle\" VALUE=\"$linkTitle\"></TD></TR>\n";
    
    print "<TR><TD>url:</TD><TD COLSPAN=2><INPUT TYPE=\"text\" MAXLENGTH=256 ".
          "SIZE=60 NAME=\"linkURL\" VALUE=\"$linkURL\"></TD></TR>\n";
    
    print "<TR><TD></TD><TD>".
          "<INPUT TYPE=\"checkbox\" NAME=\"autoAddToHotLinks\"" .
          "VALUE=\"1\">add to hot links</TD>".
          "<TD ALIGN=RIGHT>".
          "<INPUT TYPE=submit VALUE=\"update\" ".
          "NAME=\"buttonUpdate\"></TD></TR>\n";
    print "</TABLE>\n";


    print "</FORM>\n";
    

    print "</TD></TR></TABLE>\n";
    
    
    print "</TD>\n";
    

    print "<TD VALIGN=TOP WIDTH=25%>\n";

    printLinkTable( "x$linkID", 0 );
    
    print "</TD></TR></TABLE>\n";
    
    printPageFooter();

}
else {  
    #default, show node form
    
    printEditNodeForm( 0 );
} 



##
# Prints the default start node.
##
sub printStartNode {
    my $nodeID;

    if( -e "$dataDirectory/startNode" ) {
        
        $nodeID = readFileValue( "$dataDirectory/startNode" );

        # untaint
        # may have x-prefix for an external link ID
        ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
        
        printNode( $nodeID );
    }
    else {
        # we don't even have a start node
        # default to the node creation form 
        
        printEditNodeForm( 1 );
    }
}



##
# Prints the form for editing a node.
#
# Parses CGI parameters to select which node to edit.
#
# @param0 set to 1 to indicate that we are editing the first node, or 
#   0 to show the standard node edit form
##
sub printEditNodeForm {
    
    my $isFirstNode = $_[0];


    # lock to ensure integrity, including
    # --protect update of next node ID file
    # --ensure that quick ref maps are consistent with eachother
    open( LOCK_FILE, "$dataDirectory/lock" ) or die;
    flock( LOCK_FILE, 2 ) or die;

    my $nodeID = "";
    my $nodeText = "";
    if( $action eq "editNode" ) {
        $nodeID = $cgiQuery->param( "nodeID" );

        #untaint
        ( $nodeID ) = ( $nodeID =~ /(\d+)/ );

        $nodeText = readFileValue( "$dataDirectory/nodes/$nodeID.txt" );


        # replace all node links with quick-ref links

        my @linkIDs = getNodeLinks( $nodeID );

        my $linkIndex = 0;
        foreach my $link ( @linkIDs ) {
            my $quickRefTag;

            if( $linkIndex < scalar( @nodeLinkQuickReferenceTagMap ) ) {
                $quickRefTag = $nodeLinkQuickReferenceTagMap[ $linkIndex ];
            }
            else {
                # not enough tags in quickref map
                # switch to numerical index
                $quickRefTag = $linkIndex;
            }
                
            # replace direct links (<13></13>) with quick ref tags (<d></d>) 
            $nodeText =~
                s/<$link>/<$quickRefTag>/g;
            $nodeText =~
                s/<\/$link>/<\/$quickRefTag>/g;
            
            # replaced inlined title tags (<13 t>) with quick ref inlined 
            # title tags (<d t>)
            $nodeText =~
                s/<$link t>/<$quickRefTag t>/gi;

            $linkIndex ++;
        }
    }
    
    if( $nodeID eq "" ) {
        # lock to protect our file update    
        open( LOCK_FILE, "$dataDirectory/lock" ) or die;
        flock( LOCK_FILE, 2 ) or die;

        $nodeID = readFileValue( "$dataDirectory/nextNodeID" );
        
        #untaint
        ( $nodeID ) = ( $nodeID =~ /(\d+)/ );

        writeFile( "$dataDirectory/nextNodeID", $nodeID + 1 );
        
        close( LOCK_FILE );


        writeFile( "$dataDirectory/nodes/$nodeID.txt", $nodeText );
        
        writeFile( "$dataDirectory/nodes/$nodeID.links", "" );
        
        $nodeText = "";
    }
    
    
    # construct a map of quick ref tags to node IDs
    # we will use this map when the edited node is submitted to ensure
    # that the ref'd links are correct, even if the links list changes
    # (for example, by another user) between when the edit page is generated
    # and the node changes are submitted. 
    my @quickRefMapParts = ();
    
    
    


    my @linkIDs = getNodeLinks( $nodeID );
    my @hotLinkIDs = getHotLinks();
    
    my $linkNumber = 0;
    foreach my $linkID ( @linkIDs ) {
        if( $linkNumber < scalar( @nodeLinkQuickReferenceTagMap ) ) {
            # we have enough quick reference tags numbers to tag this
            # link
            my $tag = $nodeLinkQuickReferenceTagMap[ $linkNumber ]; 
            
            push( @quickRefMapParts, "$tag,$linkID" );
        }
        else {
            # not enough quick ref tags... just use link number
            push( @quickRefMapParts, "$linkNumber,$linkID" );
        }
        $linkNumber ++;
    }
        
    my $hotLinkNumber = 0;
    foreach my $hotLinkID ( @hotLinkIDs ) {
        if( $hotLinkNumber < scalar( @hotLinkQuickReferenceTagMap ) ) {
            # we have enough quick reference tags numbers to tag this
            # link
            my $tag = $hotLinkQuickReferenceTagMap[ $hotLinkNumber ]; 
            
            push( @quickRefMapParts, "$tag,$hotLinkID" );
        }
        else {
            # not enough quick ref tags... just use link number
            # preface with H to ensure that it is unique
            push( @quickRefMapParts, "H$hotLinkNumber,$hotLinkID" );
        }
        $hotLinkNumber ++;
    }
    
    my $quickRefMap = join( ";", @quickRefMapParts );


    if( $isFirstNode ) {
        printPageHeader( "edit start node" );
    }
    else {
        printPageHeader( "edit node" );
    }

    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
    
    print "<TR><TD VALIGN=TOP ALIGN=CENTER WIDTH=75%>\n";
    

    print "<BR>\n<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=90%>";
    print "<TR><TD>\n";


    print "<CENTER><FORM METHOD=POST ACTION=\"$scriptURL\">\n";

    print "<TABLE BORDER=0><TR><TD COLSPAN=2>\n";
    
    if( $isFirstNode ) {
        print "<FONT SIZE=5>edit start node</FONT><BR>\n";
    }
    else {
        print "<FONT SIZE=5>edit node</FONT><BR>\n";
    }

    print "<INPUT TYPE=\"hidden\" NAME=\"action\" VALUE=\"updateNode\">\n";
    print "<INPUT TYPE=\"hidden\" NAME=\"nodeID\" VALUE=\"$nodeID\">\n";
    
    # pass the map as a hidden variable
    print 
       "<INPUT TYPE=\"hidden\" NAME=\"quickRefMap\" VALUE=\"$quickRefMap\">\n";

    print "<TEXTAREA COLS=60 ROWS=15 NAME=\"nodeText\" WRAP=\"soft\">" .
        "$nodeText</TEXTAREA></TD></TR>\n";
    print "<TR><TD ALIGN=LEFT>".
          "<INPUT TYPE=\"checkbox\" NAME=\"autoAddToHotLinks\"" .
          "VALUE=\"1\">add to hot links</TD>\n".
          "<TD ALIGN=RIGHT>".
          "<INPUT TYPE=submit VALUE=\"update\" NAME=\"buttonUpdate\">".
          "</TD></TR></TABLE>\n";
    
    print "</FORM></CENTER>\n";

    # editing instructions 
    
    print "separate paragraphs with a blank line.\n".
          "The first paragraph will be used as the node title.".
          "<BR><BR>\n";
    print "the red characters in the link lists ".
          "(<FONT COLOR=#FF0000>$nodeLinkQuickReferenceTagMap[0]</FONT>, ".
          "<FONT COLOR=#FF0000>$nodeLinkQuickReferenceTagMap[1]</FONT>, ".
          "<FONT COLOR=#FF0000>$nodeLinkQuickReferenceTagMap[2]</FONT>, ".
          "etc.) ".
          "are quick reference tags for anchoring inline links.\n".
          "You can create an inline link using one of these tags ".
          "<TT>&lt;$nodeLinkQuickReferenceTagMap[0]&gt;like this".
          "&lt;/$nodeLinkQuickReferenceTagMap[0]&gt;</TT>.\n".
          "You can automatically insert the destination node's title as ".
          "a link in your node like this ".
          "<TT>&lt;$nodeLinkQuickReferenceTagMap[0] t&gt;</TT>.\n";    
    

    print "</TD></TR></TABLE>\n";
    
    
    print "</TD>\n";
    

    print "<TD VALIGN=TOP WIDTH=25%>\n";

    printLinkTable( $nodeID, 1 );
    
    close( LOCK_FILE );

    print "</TD></TR></TABLE>\n";
    
    printPageFooter();
}



##
# Creates a 2-way link between nodes.
#
# @param0 the first node ID, or x-prefixed external link ID.
# @param1 the second node ID, or x-prefixed external link ID.
#
# Example A:
# makeLink( 13, 10 );
#
# Example B:
# makeLink( "x13", 10 );
##
sub makeLink {
    my $firstNodeID = $_[0];
    my $secondNodeID = $_[1];

    my $firstLinkFile;
    my $secondLinkFile;

    if( $firstNodeID =~ m/x(\d+)/ ) {
        
        my $linkID = $1;
        $firstLinkFile = "$dataDirectory/externalLinks/$linkID.links";
    }
    else {
        $firstLinkFile = "$dataDirectory/nodes/$firstNodeID.links";
    }

    if( $secondNodeID =~ m/x(\d+)/ ) {
        
        my $linkID = $1;
        $secondLinkFile = "$dataDirectory/externalLinks/$linkID.links";
    }
    else {
        $secondLinkFile = "$dataDirectory/nodes/$secondNodeID.links";
    }


    # make sure link does not already exist 
    my $exists = 0;

    # all links are 2-way, so we only need to test for existence in 1 direction
    my $oldLinksText = readFileValue( $firstLinkFile );

    # split by lines
    my @oldLinkIDs = split( /\n/, $oldLinksText );
    
    foreach my $oldID ( @oldLinkIDs ) {

        if( $oldID eq $secondNodeID ) {
            $exists = 1;
        }
    }

    if( not $exists ) {
        addToFile( $firstLinkFile, 
                   "$secondNodeID\n"  );
        # if we are linking a node to itself, only add once
        if( $firstNodeID ne $secondNodeID ) {
            addToFile( $secondLinkFile, 
                       "$firstNodeID\n"  );
        }
    }
}



##
# Removes a 2-way link between nodes.
#
# @param0 the first node ID.
# @param1 the second node ID.
##
sub removeLink {
    my $firstNodeID = $_[0];
    my $secondNodeID = $_[1];
    
    # lock to protect our file updates    
    open( LOCK_FILE, "$dataDirectory/lock" ) or die;
    flock( LOCK_FILE, 2 ) or die;

    removeLinkOneWay( $firstNodeID, $secondNodeID );
    removeLinkOneWay( $secondNodeID, $firstNodeID );

    close( LOCK_FILE );
}



##
# Removes a 1-way link between nodes.
#
# Used as a sub-routine of removeLink.
# Should not be called directly.
#
# @param0 the first node ID (the link source).
# @param1 the second node ID (the link destination).
##
sub removeLinkOneWay {
    my $firstNodeID = $_[0];
    my $secondNodeID = $_[1];
    
    my $isFirstExternal;
    my $firstLinkFile;

    if( $firstNodeID =~ m/x(\d+)/ ) {
        $firstNodeID = $1;
        $isFirstExternal = 1;

        $firstLinkFile = "$dataDirectory/externalLinks/$firstNodeID.links";
    }
    else {
        $isFirstExternal = 0;
        
        $firstLinkFile = "$dataDirectory/nodes/$firstNodeID.links";
    }
    
    if( not $isFirstExternal ) {
        my $nodeText = 
            readFileValue( "$dataDirectory/nodes/$firstNodeID.txt" );

        # remove any in-line links from the text
        $nodeText =~
            s/<$secondNodeID>//g;
        $nodeText =~
            s/<\/$secondNodeID>//g;
        
        # replace any node title links with the actual node title
        # (this keeps the text consistent, though the node title
        #  may fall out of synch in the future since the link no
        #  longer exists)

        my $secondNodeTitle = getNodeTitle( $secondNodeID );

        $nodeText =~
            s/<$secondNodeID t>/$secondNodeTitle/gi;
                

        writeFile( "$dataDirectory/nodes/$firstNodeID.txt", $nodeText );
    }

    
    my $oldLinksText = 
        readFileValue( $firstLinkFile );
    
    # and if our links list is not empty already
    if( $oldLinksText ne "" ) {
        
        # split by lines
        my @oldLinkIDs = split( /\n/, $oldLinksText );

        # build a new list
        my @newLinkIDs = ();
        
        foreach my $oldID ( @oldLinkIDs ) {
            
            if( $secondNodeID ne $oldID ) {
                push( @newLinkIDs, "$oldID\n" );
            }
            # else drop the ID
        }
        
        my $newLinkText = join( "", @newLinkIDs );
        writeFile( $firstLinkFile, $newLinkText );
    }
                
}



##
# Adds a node or external link to the hot links list.
#
# @param0 the node ID, or x-prefixed external link ID.
#
# Example A:
# makeLink( 13);
#
# Example B:
# makeLink( "x13" );
##
sub addToHotLinks {
    my $nodeID = $_[0];
    
    # make sure node not already in list 
    my $exists = 0;


    # lock to protect our file update    
    open( LOCK_FILE, "$dataDirectory/lock" ) or die;
    flock( LOCK_FILE, 2 ) or die;

    my $oldLinksText = readFileValue( "$dataDirectory/hot.links" );
    
    # split by lines
    my @oldLinkIDs = split( /\n/, $oldLinksText );
    
    foreach my $oldID ( @oldLinkIDs ) {

        if( $oldID eq $nodeID ) {
            $exists = 1;
        }
    }

    if( not $exists ) {
        addToFile( "$dataDirectory/hot.links", "$nodeID\n" );
    }

    close( LOCK_FILE );
}



##
# Prints the full HTML display for a node or external link.
#
# @param0 the node ID, or an x-prefixed external link ID.
#
# Example A:
# printNode( "13" );
#
# Example B:
# printNode( "x13" );
##
sub printNode {
    my $nodeID = $_[0];

    if( $nodeID eq "" ) {
        $nodeID = 0;
    }

    my $isExternal;
    if( $nodeID =~ m/x(\d+)/ ) {
        # an external link
        
        # get just the numerical portion (without the "x")
        $nodeID = $1;
       
        $isExternal = 1;
    }
    else {
        # an internal node
        $isExternal = 0;
    }
    
    my $nodeTitle;
    my @nodeElements;
    
    if( $isExternal ) {
        $nodeTitle = getNodeTitle( "x$nodeID" );
        my $nodeURL = getExternalLinkURL( $nodeID ); 
        
        @nodeElements = 
            ( "<A HREF=\"$nodeURL\"><FONT COLOR=#00A000>$nodeURL</FONT></A>" );
    }
    else {
        
        my $nodeText;
        
        if( -e "$dataDirectory/nodes/$nodeID.txt" ) {
            $nodeText = readFileValue( "$dataDirectory/nodes/$nodeID.txt" );
        }
        else {
            $nodeText = "node does not exist";
        }

        # convert non-standard paragraph breaks (with extra whitespace)
        # to newline-newline breaks
        $nodeText =~ s/\s*\n\s*\n\s*\n/\n\n/g;
    

        # split into paragraphs
        @nodeElements = split( /\n\n/, $nodeText );

        $nodeTitle = shift( @nodeElements );
    }

    printPageHeader( $nodeTitle );

    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
        
    print "<TR><TD VALIGN=TOP ALIGN=CENTER WIDTH=75%>\n";
    
        
    print "<BR>\n<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=90%>" .
          "<TR><TD>\n";

    print "<FONT SIZE=5>$nodeTitle</FONT>";
    if( not $readOnlyMode ) {
        if( $isExternal ) {
            print 
           " [<A HREF=\"$scriptURL?action=editExternalLink&linkID=$nodeID\">" .
           "edit</A>]\n"; 
            print 
                " [<A HREF=\"$scriptURL?action=addToHotLinks&nodeID=x$nodeID&".
                "showNodeID=x$nodeID\">". 
                "hot link</A>]";
        }
        else {
            print " [<A HREF=\"$scriptURL?action=editNode&nodeID=$nodeID\">" . 
                  "edit</A>]\n"; 
            print 
                " [<A HREF=\"$scriptURL?action=addToHotLinks&nodeID=$nodeID&".
                "showNodeID=$nodeID\">". 
                "hot link</A>]";
        }
    }

    print "<BR><BR>\n";

    foreach my $paragraph ( @nodeElements ) {
        # search for link start tags, like <13>, and replace them
        # with HTML links to show the node (example:  show node 13)
        $paragraph =~ 
            s/<(\d+)>/<A HREF="$scriptURL?action=showNode&nodeID=$1">/g;
        
        # search for link end tags, like </13>, and replace them
        # with HTML link end tags, </A>
        $paragraph =~ 
            s/<\/\d+>/<\/A>/g;

        
        # search for external link start/end tags, like <x13> or </x13>, and 
        # replace them with colored HTML link tags
        # the /e regexp modifier forces evaluation of the right side, so
        # we can call the getExternalLinkURL subroutine
        $paragraph =~ 
            s/<x(\d+)>/
              "<A HREF=\"" .
              getExternalLinkURL( $1 ) .
              "\"><FONT COLOR=\#00A000>"/ge;

        # search for external link end tags, like </x13>, and replace
        # them with HTML tags to end the font color and end the link,
        # </FONT></A>
        $paragraph =~ 
            s/<\/x\d+>/<\/FONT><\/A>/g;
        
        
        # search for inlined title links like <13 t>, and 
        # replace them with HTML links anchored to titles.
        # the /e regexp modifier forces evaluation of the right side, so
        # we can call the getNodeTitle subroutine
        $paragraph =~ 
            s/<(\d+) t>/
              "<A HREF=\"$scriptURL?action=showNode&nodeID=$1\">" . 
              getNodeTitle( $1 ) . 
              "<\/A>"/gei;

        # search for inlined title external links like <x13 t>, and 
        # replace them with colored HTML links anchored to titles.
        # again, the /e modifier allows us to call subroutines
        $paragraph =~ 
            s/<x(\d+) t>/
              "<A HREF=\"" .
              getExternalLinkURL( $1 ) .
              "\"><FONT COLOR=\#00A000>" .
              getNodeTitle( "x$1" ) .
              "<\/FONT><\/A>"/gei;

        
        # search for single-\n breaks and replace them with <BR>
        $paragraph =~ 
            s/\n/<BR>/g;

        print "$paragraph<BR><BR>\n";        
    }
        
    print "</TD></TR></TABLE>\n";
    
    
    print "</TD>\n";
    

    print "<TD VALIGN=TOP WIDTH=25%>\n";

    if( $isExternal ) {
        printLinkTable( "x$nodeID", 0 );
    }
    else {
        printLinkTable( $nodeID, 0 );
    }

    print "</TD></TR></TABLE>\n";

    printPageFooter();
}



##
# Prints an HTML table of node links and hot links.
#
# @param0 the node ID.
# @param1 a flag set to 1 to include quick-reference enumeration (1, 2, 3, 
#   etc.) or 0 to include no enumeration.
#
# Example:
# printLinkTable( "13", 1 );
##
sub printLinkTable {
    my $nodeID = $_[0];
    my $showEnumeration = $_[1];
    
    print "<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 WIDTH=100%>\n";
    print "<TR><TD VALIGN=TOP>\n";

    
    print "<BR>\n";

    print "<TABLE CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
    print "<TR><TD BGCOLOR=#C0C0C0>this node's links:</TD></TR>\n";
    print "<TR><TD BGCOLOR=#E0E0E0>\n";
    printNodeLinks( $nodeID, $showEnumeration );
    print "</TD></TR></TABLE>\n";

    print "<BR>\n";

    print "<TABLE CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
    print "<TR><TD BGCOLOR=#C0C0C0>hot links:</TD></TR>\n";
    print "<TR><TD BGCOLOR=#E0E0E0>\n";
    printHotLinks( $nodeID, $showEnumeration );
    print "</TD></TR></TABLE>\n";


    print "</TD></TR></TABLE>\n";
}



##
# Prints an HTML list of node links.
#
# @param0 the node ID.
# @param1 a flag set to 1 to include quick-reference enumeration (C, D, E, 
#   etc.) or 0 to include no enumeration.
#
# Example:
# printNodeLinks( "13", 0 );
##
sub printNodeLinks {
    my $nodeID = $_[0];
    my $showEnumeration = $_[1];

    my @linkIDs = getNodeLinks( $nodeID );

    # optimization
    # avoid re-printing in inner loop
    my $opt_hotLinkStartString = 
        " (<A HREF=\"$scriptURL?action=addToHotLinks&";

    
    if( scalar( @linkIDs ) > 0 ) {
        print "<FORM ACTION=\"$scriptURL\" METHOD=POST>\n";

        print 
            "<INPUT TYPE=\"hidden\" NAME=\"action\" VALUE=\"removeLinks\">\n";
        print 
            "<INPUT TYPE=\"hidden\" NAME=\"firstNodeID\" VALUE=\"$nodeID\">\n";
        
        print "<TABLE BORDER=0>\n";

        my $linkNumber = 0;
        foreach my $id ( @linkIDs ) {
            my $title = getNodeTitle( $id );
            

            print "<TR>";

            if( $showEnumeration ) {
                
                
                my $quickRefTag;
                if( $linkNumber < scalar( @nodeLinkQuickReferenceTagMap ) ) {
                    # we have enough quick reference tags numbers to tag this
                    # link
                    $quickRefTag = $nodeLinkQuickReferenceTagMap[$linkNumber]; 
                }
                else {
                    # use the link number as the quick ref tag 
                    $quickRefTag = $linkNumber;
                }
                
                print "<TD VALIGN=MIDDLE><FONT COLOR=#FF0000>$quickRefTag".
                      "</FONT></TD>";
            }
            if( not $readOnlyMode ) {
                print "<TD VALIGN=MIDDLE>" .
                      "<INPUT TYPE=\"checkbox\" NAME=\"secondNodeID\"" .
                      "VALUE=\"$id\"></TD>";
            }

            if( $id =~ m/x(\d+)/ ) {
                # external link
                my $linkID = $1;
                my $linkTitle = getNodeTitle( "x$linkID" );
                my $linkURL = getExternalLinkURL( $linkID );

                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$linkURL\"><FONT COLOR=#00A000>".
                      "$linkTitle</FONT></A>";
                
                if( not $readOnlyMode ) {
                    print $opt_hotLinkStartString;
                    print "nodeID=$id&showNodeID=$nodeID\">h</A>) ".
                          "(<A HREF=\"$scriptURL?action=showNode&".
                          "nodeID=$id\">v</A>)</TD></TR>\n";
                }
            }
            else {
                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$scriptURL?action=showNode&nodeID=$id\">".
                      "$title</A>";
                if( not $readOnlyMode ) {
                    print $opt_hotLinkStartString;
                    print "nodeID=$id&showNodeID=$nodeID\">h</A>)</TD></TR>\n";
                }
            }

            $linkNumber++;            
        }
        print "</TABLE>\n";

        if( not $readOnlyMode ) {
            print "<INPUT TYPE=\"submit\" VALUE=\"remove marked\">\n";
        }
        print "</FORM>\n";
    }
    
}



##
# Gets the nodes linked from a node (or linked from an external link).
#
# @param0 the node ID to get links for, or an x-prefixed external link ID.
#
# @return a list of linked node IDs.
#
# Example A:
# my @linkedIDs = getNodeLinks( 13 );
#
# Example B:
# my @linkedIDs = getNodeLinks( "x13" );
##
sub getNodeLinks {
    my $nodeID = $_[0];
    
    my $linksText;
    
    if( $nodeID =~ m/x(\d+)/ ) {
        # arg $1 gets the (\d+) part of the match
        my $externalLinkID = $1;
        
        if( -e "$dataDirectory/externalLinks/$externalLinkID.links" ) {
            $linksText = readFileValue( 
                   "$dataDirectory/externalLinks/$externalLinkID.links" );
        }
        else {
            $linksText = "";
        }
    }
    else {
        if( -e "$dataDirectory/nodes/$nodeID.links" ) {   
            $linksText = readFileValue( "$dataDirectory/nodes/$nodeID.links" );
        }
        else {
            $linksText = "";
        }
    }

    # split by lines
    my @linkIDs = split( /\n/, $linksText );

    my @untaintedIDs = ();

    foreach my $id ( @linkIDs ) {
        #untaint
        ( $id ) = ( $id =~ /(x?\d+)/ );
        
        push( @untaintedIDs, $id );
    }

    return @untaintedIDs;
}



##
# Gets the nodes on th hot links list.
#
# @return a list of linked node IDs and external link IDs.
#
# Example:
# my @linkedIDs = getHotLinks();
##
sub getHotLinks {
    my $linksText = readFileValue( "$dataDirectory/hot.links" );
    
    # split by lines
    my @linkIDs = split( /\n/, $linksText );

    my @untaintedIDs = ();

    foreach my $id ( @linkIDs ) {
        #untaint
        ( $id ) = ( $id =~ /(x?\d+)/ );
        
        push( @untaintedIDs, $id );
    }

    return @untaintedIDs;
}



##
# Prints an HTML list of hot links.
#
# @param0 the node ID that the table is being created for.
# @param1 a flag set to 1 to include quick-reference enumeration (C, D, E, 
#   etc.) or 0 to include no enumeration.
#
# Example:
# printHotLinks( "13", 1 );
##
sub printHotLinks {
    my $nodeID = $_[0];
    my $showEnumeration = $_[1];

    my @linkIDs = getHotLinks();
    
    if( scalar( @linkIDs ) > 0 ) {
        if( not $readOnlyMode ) {
            print "(click \"+\" to complete a link)";
        }
    
        print "<FORM ACTION=\"$scriptURL\" METHOD=POST>\n";
        print 
          "<INPUT TYPE=\"hidden\" NAME=\"action\" VALUE=\"removeHotLinks\">\n";
        print "<INPUT TYPE=\"hidden\" NAME=\"nodeID\" VALUE=\"$nodeID\">\n";
        
        print "<TABLE BORDER=0>\n";
        
        my $linkNumber = 0;
        foreach my $id ( @linkIDs ) {
            print "<TR>";

            if( $showEnumeration ) {
                my $quickRefTag;

                if( $linkNumber < scalar( @hotLinkQuickReferenceTagMap ) ) {
                    # we have enough quick reference tags numbers to tag this
                    # link
                    $quickRefTag = $hotLinkQuickReferenceTagMap[$linkNumber]; 
                }
                else {
                    # use the H-prefixed link number as the quick ref tag 
                    $quickRefTag = "H$linkNumber";
                }
                
                print "<TD VALIGN=MIDDLE><FONT COLOR=#FF0000>$quickRefTag".
                      "</FONT></TD>";
            }


            my $title = getNodeTitle( $id );
            
            if( not $readOnlyMode ) {
                print "<TD VALIGN=MIDDLE>" .
                      "<INPUT TYPE=\"checkbox\" NAME=\"idToRemove\"" .
                      " VALUE=\"$id\"></TD>";
                print "<TD VALIGN=MIDDLE>" .
                  "[<A HREF=\"$scriptURL?action=makeLink&firstNodeID=$nodeID" .
                  "&secondNodeID=$id\">+</A>]</TD>";
            }

            if( $id =~ m/x(\d+)/ ) {
                # external link
                my $linkID = $1;
                my $linkTitle = getNodeTitle( "x$linkID" );
                my $linkURL = getExternalLinkURL( $linkID );
                
                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$linkURL\"><FONT COLOR=#00A000>".
                          "$linkTitle</FONT></A>";
                if( not $readOnlyMode ) {
                      print " (<A HREF=\"$scriptURL?action=showNode&".
                          "nodeID=x$linkID\">v</A>)</TD></TR>\n";
                  }
            }
            else {
                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$scriptURL?action=showNode&nodeID=$id\">" .
                      "$title</A></TD></TR>\n";
            }

            $linkNumber++;
        }
        print "</TABLE>\n";
        
        if( not $readOnlyMode ) {
            print "<INPUT TYPE=\"submit\" VALUE=\"remove marked\">\n";
        }
        print "</FORM>\n";
    }

}



##
# Prints the HTML header for a page.
#
# @param0 the title of the page.
#
# Example:
# printPageHeader( "My Node" );
##
sub printPageHeader {
    my $title = $_[0];

    print 
        "<HTML>\n" . 
        "<HEAD><TITLE>silk: $title</TITLE></HEAD>\n" .
        "<BODY BGCOLOR=#FFFFFF TEXT=#000000 LINK=#0000FF VLINK=#0000FF " . 
        "ALINK=#FF0000>\n";
    
    print "<TABLE WIDTH=100% CELLPADDING=0 CELLSPACING=0 BORDER=0>" .
        "<TR><TD BGCOLOR=#C0C0C0>";

    print "<TABLE BORDER=0 WIDTH=100% CELLPADDING=0 CELLSPACING=0><TR><TD>\n";
    
    print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0><TR>";
    print "<TD><FONT SIZE=7>silk</FONT></TD>\n";
    
    print "<TD>\n";
    
    if( not $requirePassword
        or ( $requirePassword and $passwordCorrect )
        or $readOnlyMode ) {
        print "-<A HREF=\"$scriptURL?action=showStartNode\">".
              "go to start node</A><BR>\n";
    }
    if( not $requirePassword 
        or ( $requirePassword and $passwordCorrect ) ) {
        print "-<A HREF=\"$scriptURL?action=newNode\">new node</A><BR>\n";
        print "-<A HREF=\"$scriptURL?action=newExternalLink\">" . 
            "new external link</A>\n";
    }
    print "</TD>\n";
    print "</TR></TABLE>\n";
    
    print "</TD>\n";

    if( $requirePassword and $passwordCorrect ) {
        print "<TD ALIGN=RIGHT>";
        if( $readOnlyMode ) {
            print "read-only mode<BR>\n";
        }
        print
            "[<A HREF=\"$scriptURL?action=logout\">logout</A>]</TD>\n";
    }
    
    print "</TR></TABLE>\n";

    print "</TD></TR></TABLE>\n";

}



##
# Prints the HTML footer for a page.
##
sub printPageFooter {    
    print "<BR><TABLE BORDER=0 WIDTH=100%><TR>\n";

    if( $allowTarballBackupOperations ) {
        if( not $requirePassword 
            or ( $requirePassword and $passwordCorrect )
            or $readOnlyMode ) {
            print 
              "<TD ALIGN=RIGHT><A HREF=\"$scriptURL?action=getDataTarball\">".
              "get backup tarball</A><BR>\n";
            if( not $readOnlyMode ) {
                print "<A HREF=\"$scriptURL?action=showRestoreForm\">".
                      "restore from tarball</A></TD>\n";
            }
            else {
                print "</TD>\n";
            }
        }
    }

    print "</TR></TABLE>\n";

    print"</BODY></HTML>";
}



##
# Gets the title of a node (or an external link).
#
# @param0 the node ID, or an x-prefixed external link ID.
#
# @return the node's (or external link's) title.
#
# Example A:
# my $title = getNodeTitle( "13" );
#
# Example B:
# my $title = getNodeTitle( "x13" );
##
sub getNodeTitle {
    my $nodeID = $_[0];

    if( $nodeID =~ m/x(\d+)/ ) {
        # external link
        # extract the \d+ part of the matched regexp
        my $linkID = $1;
        
        my $title = 
            readFileValue( "$dataDirectory/externalLinks/$linkID.title" );
        
        return $title;
    }
    else {
        open( FILE, "$dataDirectory/nodes/$nodeID.txt" ) or die;
        flock( FILE, 1 ) or die;
        
        # read the first line of the file
        my $nodeTitle = <FILE>;
        chomp( $nodeTitle );
        
        close( FILE );

        return $nodeTitle;
    }
}



##
# Gets the URL of an external link.
#
# @param0 the link ID, without an x prefix.
#
# @return the link's URL.
#
# Example A:
# my $url = getExternalLinkURL( "13" );
##
sub getExternalLinkURL {
    my $linkID = $_[0];
    
    my $linkURL = 
        readFileValue( "$dataDirectory/externalLinks/$linkID.url" );
    
    return $linkURL;
}



sub setupDataDirectory {
    
    if( not -e "$dataDirectory/nodes" ) {
        makeDirectory( "$dataDirectory/nodes", oct( "0777" ) );
    }
    
    if( not -e "$dataDirectory/externalLinks" ) {
        makeDirectory( "$dataDirectory/externalLinks", oct( "0777" ) );
    }

    if( not -e "$dataDirectory/lock" ) {
        writeFile( "$dataDirectory/lock", "" );
    }    
    if( not -e "$dataDirectory/hot.links" ) {
        writeFile( "$dataDirectory/hot.links", "" );
    }
    if( not -e "$dataDirectory/nextNodeID" ) {
        writeFile( "$dataDirectory/nextNodeID", "0" );
    }
    
    if( not -e "$dataDirectory/nextExternalLinkID" ) {
        writeFile( "$dataDirectory/nextExternalLinkID", "0" );
    }

}






##
# Reads file as a string.
#
# @param0 the name of the file.
#
# @return the file contents as a string.
#
# Example:
# my $value = readFileValue( "myFile.txt" );
##
sub readFileValue {
    my $fileName = $_[0];
    open( FILE, "$fileName" ) or die;
    flock( FILE, 1 ) or die;

    # read the entire file, set the <> separator to nothing
    local $/;

    my $value = <FILE>;
    close FILE;

    return $value;
}



##
# Checks if a file exists.
#
# @param0 the name of the file.
#
# @return 1 if it exists, and 0 otherwise.
#
# Example:
# $exists = doesFileExist( "myFile.txt" );
##
sub doesFileExist {
    my $fileName = $_[0];
    if( -e $fileName ) {
        return 1;
    }
    else {
        return 0;
    }
}

##
# Writes a string to a file.
#
# @param0 the name of the file.
# @param1 the string to print.
#
# Example:
# writeFile( "myFile.txt", "the new contents of this file" );
##
sub writeFile {
    my $fileName = $_[0];
    my $stringToPrint = $_[1];
    
    open( FILE, ">$fileName" ) or die;
    flock( FILE, 2 ) or die;

    print FILE $stringToPrint;
        
    close FILE;
}



##
# Appends a string to a file.
#
# @param0 the name of the file.
# @param1 the string to append.
#
# Example:
# addToFile( "myFile.txt", "the new contents of this file" );
##
sub addToFile {
    my $fileName = $_[0];
    my $stringToPrint = $_[1];
        
    open( FILE, ">>$fileName" ) or die;
    flock( FILE, 2 ) or die;
        
    print FILE $stringToPrint;
        
    close FILE;
}



##
# Deletes a file.
#
# @param0 the name of the file.
#
# Example:
# deleteFile( "myFile.txt" );
##
sub deleteFile {
    my $fileName = $_[0];
    
    unlink( $fileName );
}



##
# Makes a directory.
#
# @param0 the name of the directory.
# @param1 the octal permission mask.
#
# Example:
# makeDirectory( "myDir", oct( "0777" ) );
##
sub makeDirectory {
    my $fileName = $_[0];
    my $permissionMask = $_[1];
    
    mkdir( $fileName, $permissionMask );
}

