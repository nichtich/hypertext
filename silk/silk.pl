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
#



# settings that can be customized to a specific system setup

# where silk will store its data files.
# must be writable to the process that runs CGI scripts on your web server
# you should also edit the $dataDirectory variable for the error log below
my $dataDirectory = "../cgi-data/silk";

# the external URL for the silk script
my $scriptURL = "http://localhost/cgi-bin/silk.pl";

# set to 1 to require password, or 0 to allow public access
my $requirePassword = 0;

# If a password is required, the password will be set the first
#   time the silk script is run.  The MD5 hash of the password is stored
#   in the "password.md5" file in the data directory.
# To reset the password (so that the script asks for it again)
#   delete the password.md5 file.
# For best security, manually make password.md5 read-only after it has been
#   created by the script (especially if you are using a shared web server
#   that runs CGI scripts as "nobody")


# setup a local error log
BEGIN {
    my $dataDirectory = "../cgi-data/silk";
    use CGI::Carp qw(carpout);
    open(LOG, ">>$dataDirectory/errors.log") or
        die("Unable to open $dataDirectory/errors.log: $!\n");
    carpout(LOG);
}


# end of customizable settings





use strict;
use CGI;                # Object-Oriented
use MD5;


# allow group to write to our data files
umask( oct( "02" ) );


setupDataDirectory();



# map for quick-reference link tags
my @nodeLinkQuickReferenceTagMap = 
    ( "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N" );
my @hotLinkQuickReferenceTagMap = 
    ( "O", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" );


# start processing the in-bound CGI query
my $cgiQuery = CGI->new();

# always set the Pragma: no-cache directive
# this feature seems to be undocumented...
$cgiQuery->cache( 1 );


my $action = $cgiQuery->param( "action" ) || '';



# if required:
# handle retrieving the user's password, checking it, and storing
# it in a cookie

# get the password cookie, if it exists
my $passwordCookie = $cgiQuery->cookie( "password" ) || '';

my $password;
my $passwordCorrect = 0;

my $passwordHashExists = -e "$dataDirectory/password.md5";

if( $requirePassword ) {
    if( $passwordCookie ne "" ) {
        $password = $passwordCookie;
    }
    elsif( $action eq "login" ) {
        $password = $cgiQuery->param( "password" ) || '';
    }

    my $md5 = new MD5;
    $md5->add( $password ); 
    my $passwordHash = $md5->hexdigest();

    if( $passwordHashExists ) {
        # check password against hash
        
        my $truePasswordHash = readFileValue( "$dataDirectory/password.md5" );

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


# set the password cookie if we have a correct password
if( $passwordCorrect ) {
    my $cookieToSet;
    
    if( $action eq "logout" ) {
        $cookieToSet = $cgiQuery->cookie( -name=>"password",
                                          -value=>"" );
        $passwordCorrect = 0;
    }
    else {
        $cookieToSet = $cgiQuery->cookie( -name=>"password",
                                          -value=>"$password",
                                          -expires=>"+1h" );
    }
    print $cgiQuery->header( -type=>'text/html',
                             -expires=>'now',
                             -Cache_control=>'no-cache',
                             -cookie=>[ $cookieToSet ] );
}
else {
    print $cgiQuery->header( -type=>'text/html', -expires=>'now',
                             -Cache_control=>'no-cache' );
}




# handle various states and user actions

if( $requirePassword and
    ( ( not $passwordHashExists and $action ne "login" )
      or ( $passwordHashExists and not $passwordCorrect ) ) ) {
    
    # show the login form

    printPageHeader( "login" );

    print "<CENTER>\n";
    print "<FORM ACTION=\"$scriptURL\">\n";

    print "<INPUT TYPE=\"hidden\" " . 
        "NAME=\"action\" VALUE=\"login\">\n";
    
    print "password: <INPUT TYPE=\"password\" MAXLENGTH=256 ".
          "SIZE=20 NAME=\"password\" VALUE=\"\">";
    print "<INPUT TYPE=submit VALUE=\"login\" NAME=\"buttonLogin\">\n";
    print "</FORM>\n";
    print "</CENTER>";

    printPageFooter();
}
elsif( $action eq "showNode" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );

    # untaint
    # may have x-prefix for an external link ID
    ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
    
    printNode( $nodeID );
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
    
    #untaint
    # may be of form  139   or of form   x139  
    ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
    
    # make sure node not already in list 
    my $exists = 0;

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
    printNode( $nodeID );
}
elsif( $action eq "removeHotLinks" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );
    
    #untaint
    ( $nodeID ) = ( $nodeID =~ /(x?\d+)/ );
    

    # idToRemove parameter might occur multiple times, once for
    # each node that is flagged for removal from the hot links list.
    my @idsToRemove = $cgiQuery->param( "idToRemove" );
    
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

    printNode( $nodeID );
}
elsif( $action eq "updateNode" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );
    
    #untaint
    ( $nodeID ) = ( $nodeID =~ /(\d+)/ );

    my $nodeText = $cgiQuery->param( "nodeText" ) || '';

    # fix "other" newline style.
    $nodeText =~ s/\r/\n/g;
            
            
    # convert non-standard paragraph breaks (with extra whitespace)
    # to newline-newline breaks
    $nodeText =~ s/\s*\n\s*\n/\n\n/g;
    
    
    # replace all quck-ref node links with direct node links

    my @linkIDs = getNodeLinks( $nodeID );

    my $linkIndex = 0;
    foreach my $link ( @linkIDs ) {
        my $quickRefTag;

        if( $linkIndex < scalar( @nodeLinkQuickReferenceTagMap ) ) {
            $quickRefTag = $nodeLinkQuickReferenceTagMap[ $linkIndex ];
        }
        else {
            # not enough tags in quickref map
            # leave node ID in place
            $quickRefTag = $link;
        }
                
        $nodeText =~
            s/<$quickRefTag>/<$link>/g;
        $nodeText =~
            s/<\/$quickRefTag>/<\/$link>/g;
        
        $linkIndex ++;
        }

    
    # replace all quck-ref hot links with direct node links and
    # add to our node link list if needed

    my @hotLinkIDs = getHotLinks();

    $linkIndex = 0;
    foreach my $hotLink ( @hotLinkIDs ) {
        my $quickRefTag;

        if( $linkIndex < scalar( @hotLinkQuickReferenceTagMap ) ) {
            $quickRefTag = $hotLinkQuickReferenceTagMap[ $linkIndex ];
        }
        else {
            # not enough tags in quickref map
            # leave node ID in place
            $quickRefTag = $hotLink;
        }
        
        if( $nodeText =~ m/<$quickRefTag>/ ) {
            # text contains a link to one of our hot links
            
            # make sure that this node is on our link list
            makeLink( $nodeID, $hotLink );
            
            # replace with direct link in text
            $nodeText =~
                s/<$quickRefTag>/<$hotLink>/g;
            $nodeText =~
                s/<\/$quickRefTag>/<\/$hotLink>/g;
        }

        $linkIndex ++;
    }
    
   
    writeFile( "$dataDirectory/nodes/$nodeID.txt", $nodeText );

    printNode( $nodeID );
}
elsif( $action eq "updateExternalLink" ) {
    my $linkID = $cgiQuery->param( "linkID" );
    
    #untaint
    ( $linkID ) = ( $linkID =~ /(\d+)/ );

    my $linkTitle = $cgiQuery->param( "linkTitle" ) || '';
    my $linkURL = $cgiQuery->param( "linkURL" ) || '';    

    writeFile( "$dataDirectory/externalLinks/$linkID.title", $linkTitle );
    writeFile( "$dataDirectory/externalLinks/$linkID.url", $linkURL );

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

        $linkTitle = 
            readFileValue( "$dataDirectory/externalLinks/$linkID.title" );
        $linkURL = 
            readFileValue( "$dataDirectory/externalLinks/$linkID.url" );
    }
    
    if( $linkID eq "" ) {
        $linkID = readFileValue( "$dataDirectory/nextExternalLinkID" );
        
        #untaint
        ( $linkID ) = ( $linkID =~ /(\d+)/ );

        writeFile( "$dataDirectory/nextExternalLinkID", $linkID + 1 );

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
    print "<TR><TD>title:</TD><TD><INPUT TYPE=\"text\" MAXLENGTH=256 ".
          "SIZE=60 NAME=\"linkTitle\" VALUE=\"$linkTitle\"></TD></TR>\n";
    
    print "<TR><TD>url:</TD><TD><INPUT TYPE=\"text\" MAXLENGTH=256 ".
          "SIZE=60 NAME=\"linkURL\" VALUE=\"$linkURL\"></TD></TR>\n";
    
    print "<TR><TD></TD><TD><INPUT TYPE=submit VALUE=\"update\" ".
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
else {  #default, show node form
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
                # leave node ID in place
                $quickRefTag = $link;
            }
                
            $nodeText =~
                s/<$link>/<$quickRefTag>/g;
            $nodeText =~
                s/<\/$link>/<\/$quickRefTag>/g;
            
            $linkIndex ++;
        }
    }
    
    if( $nodeID eq "" ) {
        $nodeID = readFileValue( "$dataDirectory/nextNodeID" );
        
        #untaint
        ( $nodeID ) = ( $nodeID =~ /(\d+)/ );

        writeFile( "$dataDirectory/nextNodeID", $nodeID + 1 );

        writeFile( "$dataDirectory/nodes/$nodeID.txt", $nodeText );
        
        writeFile( "$dataDirectory/nodes/$nodeID.links", "" );
        
        $nodeText = "";
    }

    printPageHeader( "edit node" );
    
    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
    
    print "<TR><TD VALIGN=TOP ALIGN=CENTER WIDTH=75%>\n";
    

    print "<BR>\n<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=90%>";
    print "<TR><TD>\n";

    print "<FONT SIZE=5>edit node</FONT><BR>\n";

    print "<FORM METHOD=POST ACTION=\"$scriptURL\">\n";

    print "<INPUT TYPE=\"hidden\" NAME=\"action\" VALUE=\"updateNode\">\n";
    print "<INPUT TYPE=\"hidden\" NAME=\"nodeID\" VALUE=\"$nodeID\">\n";
    
    print "<TEXTAREA COLS=60 ROWS=15 NAME=\"nodeText\" WRAP=\"soft\">" .
        "$nodeText</TEXTAREA><BR>\n";
    print "<INPUT TYPE=submit VALUE=\"update\" NAME=\"buttonUpdate\">\n";

    print "</FORM>\n";
    

    print "</TD></TR></TABLE>\n";
    
    
    print "</TD>\n";
    

    print "<TD VALIGN=TOP WIDTH=25%>\n";

    printLinkTable( $nodeID, 1 );
    
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

    removeLinkOneWay( $firstNodeID, $secondNodeID );
    removeLinkOneWay( $secondNodeID, $firstNodeID );
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
        $nodeTitle = 
            readFileValue( "$dataDirectory/externalLinks/$nodeID.title" );
        my $nodeURL = 
            readFileValue( "$dataDirectory/externalLinks/$nodeID.url" );
        
        @nodeElements = 
            ( "<A HREF=\"$nodeURL\"><FONT COLOR=#00A000>$nodeURL</FONT></A>" );
    }
    else {
        my $nodeText = readFileValue( "$dataDirectory/nodes/$nodeID.txt" );

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
    if( $isExternal ) {
        print 
          " [<A HREF=\"$scriptURL?action=editExternalLink&linkID=$nodeID\">" . 
          "edit</A>]\n"; 
        print 
          " [<A HREF=\"$scriptURL?action=addToHotLinks&nodeID=x$nodeID\">". 
          "hot link</A>]";
    }
    else {
        print " [<A HREF=\"$scriptURL?action=editNode&nodeID=$nodeID\">" . 
            "edit</A>]\n"; 
        print " [<A HREF=\"$scriptURL?action=addToHotLinks&nodeID=$nodeID\">". 
            "hot link</A>]";
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
        # replace them with HTML links
        while( $paragraph =~ m/<\/?x(\d+)>/ ) {
            my $linkID = $1;
            
            my $linkURL = 
                readFileValue( "$dataDirectory/externalLinks/$linkID.url" );
            
            $paragraph =~ 
                s/<x$linkID>/<A HREF="$linkURL"><FONT COLOR=#00A000>/g;

            $paragraph =~ 
                s/<\/x$linkID>/<\/FONT><\/A>/g;
        }

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
                print "<TD VALIGN=MIDDLE>";
                if( $linkNumber < scalar( @nodeLinkQuickReferenceTagMap ) ) {
                    # we have enough quick reference tags numbers to tag this
                    # link
                    my $tag = $nodeLinkQuickReferenceTagMap[$linkNumber]; 
                    print "$tag";
                }
                print "</TD>";
            }
            print "<TD VALIGN=MIDDLE>" .
                "<INPUT TYPE=\"checkbox\" NAME=\"secondNodeID\"" .
                "VALUE=\"$id\"></TD>";

            if( $id =~ m/x(\d+)/ ) {
                # external link
                my $linkID = $1;
                my $linkTitle = readFileValue( 
                    "$dataDirectory/externalLinks/$linkID.title" );
                my $linkURL = readFileValue( 
                    "$dataDirectory/externalLinks/$linkID.url" );
                
                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$linkURL\"><FONT COLOR=#00A000>".
                      "$linkTitle</FONT></A> ".
                      "(<A HREF=\"$scriptURL?action=showNode&".
                      "nodeID=x$linkID\">v</A>)</TD></TR>\n";
            }
            else {
                print "<TD VALIGN=MIDDLE>" .
                    "<A HREF=\"$scriptURL?action=showNode&nodeID=$id\">".
                    "$title</A></TD></TR>\n";
            }

            $linkNumber++;            
        }
        print "</TABLE>\n";

        print "<INPUT TYPE=\"submit\" VALUE=\"remove marked\">\n";
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
        $linksText = 
            readFileValue( 
                "$dataDirectory/externalLinks/$externalLinkID.links" );
        }
    else {
        $linksText = readFileValue( "$dataDirectory/nodes/$nodeID.links" );
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
        print "(click \"+\" to complete a link)";
    
        print "<FORM ACTION=\"$scriptURL\" METHOD=POST>\n";
        print 
          "<INPUT TYPE=\"hidden\" NAME=\"action\" VALUE=\"removeHotLinks\">\n";
        print "<INPUT TYPE=\"hidden\" NAME=\"nodeID\" VALUE=\"$nodeID\">\n";
        
        print "<TABLE BORDER=0>\n";
        
        my $linkNumber = 0;
        foreach my $id ( @linkIDs ) {
            print "<TR>";

            if( $showEnumeration ) {
                print "<TD VALIGN=MIDDLE>";
                if( $linkNumber < scalar( @hotLinkQuickReferenceTagMap ) ) {
                    # we have enough quick reference tags numbers to tag this
                    # link
                    my $tag = $hotLinkQuickReferenceTagMap[$linkNumber]; 
                    print "$tag";
                }
                print "</TD>";
            }


            my $title = getNodeTitle( $id );
            
            
            print "<TD VALIGN=MIDDLE>" .
                "<INPUT TYPE=\"checkbox\" NAME=\"idToRemove\"" .
                " VALUE=\"$id\"></TD>";
            print "<TD VALIGN=MIDDLE>" .
                "[<A HREF=\"$scriptURL?action=makeLink&firstNodeID=$nodeID" .
                "&secondNodeID=$id\">+</A>]</TD>";

            if( $id =~ m/x(\d+)/ ) {
                # external link
                my $linkID = $1;
                my $linkTitle = readFileValue( 
                    "$dataDirectory/externalLinks/$linkID.title" );
                my $linkURL = readFileValue( 
                    "$dataDirectory/externalLinks/$linkID.url" );
                
                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$linkURL\"><FONT COLOR=#00A000>".
                      "$linkTitle</FONT></A> ".
                      "(<A HREF=\"$scriptURL?action=showNode&".
                      "nodeID=x$linkID\">v</A>)</TD></TR>\n";
            }
            else {
                print "<TD VALIGN=MIDDLE>" .
                      "<A HREF=\"$scriptURL?action=showNode&nodeID=$id\">" .
                      "$title</A></TD></TR>\n";
            }

            $linkNumber++;
        }
        print "</TABLE>\n";
        print "<INPUT TYPE=\"submit\" VALUE=\"remove marked\">\n";
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
    print "<TD>-<A HREF=\"$scriptURL\">new node</A><BR>\n";
    print "-<A HREF=\"$scriptURL?action=newExternalLink\">" . 
        "new external link</A></TD>\n";
    print "</TR></TABLE>\n";
    
    print "</TD>\n";

    if( $requirePassword and $passwordCorrect ) {
        print "<TD ALIGN=RIGHT>".
            "[<A HREF=\"$scriptURL?action=logout\">logout</A>]</TD>\n";
    }
    
    print "</TR></TABLE>\n";

    print "</TD></TR></TABLE>\n";

}



##
# Prints the HTML footer for a page.
##
sub printPageFooter {
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
        my $nodeText = readFileValue( "$dataDirectory/nodes/$nodeID.txt" );

        # split into paragraphs
        my @nodeElements = split( /\n\n/, $nodeText );
        
        my $nodeTitle = shift( @nodeElements );
    
        return $nodeTitle;
    }
}



sub setupDataDirectory {
    
    if( not -e "$dataDirectory/nodes" ) {
        makeDirectory( "$dataDirectory/nodes", oct( "0777" ) );
    }
    
    if( not -e "$dataDirectory/externalLinks" ) {
        makeDirectory( "$dataDirectory/externalLinks", oct( "0777" ) );
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

    my @lineList = <FILE>;

    my $value = join( "", @lineList );

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

