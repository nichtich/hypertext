#!/usr/bin/perl -wT

#
# Modification History
#
# 2004-March-16   Jason Rohrer
# Created.
#



# settings that can be customized to a specific system setup
my $dataDirectory = "../cgi-data/silk";
my $scriptURL = "http://localhost/cgi-bin/silk.pl";


# end of customizable settings

# setup a local error log
#use CGI::Carp qw(carpout);
BEGIN {
    my $dataDirectory = "../cgi-data/silk";
    use CGI::Carp qw(carpout);
    open(LOG, ">>$dataDirectory/errors.log") or
        die("Unable to open $dataDirectory/errors.log: $!\n");
    carpout(LOG);
}



use strict;
use CGI;                # Object-Oriented


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

print $cgiQuery->header( -type=>'text/html', -expires=>'now',
                         -Cache_control=>'no-cache' );

if( $action eq "showNode" ) {
    my $nodeID = $cgiQuery->param( "nodeID" );

    #untaint
    ( $nodeID ) = ( $nodeID =~ /(\d+)/ );
    
    printNode( $nodeID );
}
elsif( $action eq "makeLink" ) {
    my $firstNodeID = $cgiQuery->param( "firstNodeID" );
    my $secondNodeID = $cgiQuery->param( "secondNodeID" );

    #untaint
    ( $firstNodeID ) = ( $firstNodeID =~ /(\d+)/ );
    ( $secondNodeID ) = ( $secondNodeID =~ /(\d+)/ );
    
    
    if( $firstNodeID ne "" and $secondNodeID ne "" ) {
        makeLink( $firstNodeID, $secondNodeID );
    }

    printNode( $firstNodeID );
}
elsif( $action eq "removeLinks" ) {
    my $firstNodeID = $cgiQuery->param( "firstNodeID" );
    
    #untaint
    ( $firstNodeID ) = ( $firstNodeID =~ /(\d+)/ );

    if( $firstNodeID ne "" ) {
        my @idsToRemove = $cgiQuery->param( "secondNodeID" );
        
        foreach my $secondNodeID ( @idsToRemove ) {
            # untaint
            ( $secondNodeID ) = ( $secondNodeID =~ /(\d+)/ );
    
    
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
    ( $nodeID ) = ( $nodeID =~ /(\d+)/ );
    
    # make sure node not already in list 
    my $exists = 0;

    my $oldLinksText = readFileValue( "$dataDirectory/hot.links" );
    
    # split by lines
    my @oldLinkIDs = split( /\n/, $oldLinksText );
    
    foreach my $oldID ( @oldLinkIDs ) {

        if( $oldID == $nodeID ) {
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
    ( $nodeID ) = ( $nodeID =~ /(\d+)/ );
    

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
                if( $id == $oldID ) {
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
    

    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=90%><TR><TD>\n";

    print "<FONT SIZE=7>edit node</FONT><BR>\n";

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
# @param0 the first node ID.
# @param1 the second node ID.
##
sub makeLink {
    my $firstNodeID = $_[0];
    my $secondNodeID = $_[1];

    # make sure link does not already exist 
    my $exists = 0;

    # all links are 2-way, so we only need to test for existence in 1 direction
    my $oldLinksText = 
        readFileValue( "$dataDirectory/nodes/$firstNodeID.links" );
    
    # split by lines
    my @oldLinkIDs = split( /\n/, $oldLinksText );
    
    foreach my $oldID ( @oldLinkIDs ) {

        if( $oldID == $secondNodeID ) {
            $exists = 1;
        }
    }

    if( not $exists ) {
        addToFile( "$dataDirectory/nodes/$firstNodeID.links", 
                   "$secondNodeID\n"  );
        # if we are linking a node to itself, only add once
        if( $firstNodeID != $secondNodeID ) {
            addToFile( "$dataDirectory/nodes/$secondNodeID.links", 
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
    
    my $nodeText = readFileValue( "$dataDirectory/nodes/$firstNodeID.txt" );

    # remove any in-line links from the text
    $nodeText =~
        s/<$secondNodeID>//g;
    $nodeText =~
        s/<\/$secondNodeID>//g;
    
    writeFile( "$dataDirectory/nodes/$firstNodeID.txt", $nodeText );

    my $oldLinksText = 
        readFileValue( "$dataDirectory/nodes/$firstNodeID.links" );
    
    # and if our links list is not empty already
    if( $oldLinksText ne "" ) {
        
        # split by lines
        my @oldLinkIDs = split( /\n/, $oldLinksText );

        # build a new list
        my @newLinkIDs = ();
        
        foreach my $oldID ( @oldLinkIDs ) {
            
            if( $secondNodeID != $oldID ) {
                push( @newLinkIDs, "$oldID\n" );
            }
            # else drop the ID
        }
        
        my $newLinkText = join( "", @newLinkIDs );
        writeFile( "$dataDirectory/nodes/$firstNodeID.links", $newLinkText );
    }
                
}



##
# Prints the full HTML display for a node.
#
# @param0 the node ID.
#
# Example:
# printNode( "13" );
##
sub printNode {
    my $nodeID = $_[0];

    if( $nodeID eq "" ) {
        $nodeID = 0;
    }
    
    my $nodeText = readFileValue( "$dataDirectory/nodes/$nodeID.txt" );

    # split into paragraphs
    my @nodeElements = split( /\n\n/, $nodeText );

    my $nodeTitle = shift( @nodeElements );

    printPageHeader( $nodeTitle );

    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=100%>\n";
    
    print "<TR><TD VALIGN=TOP ALIGN=CENTER WIDTH=75%>\n";
    

    print "<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 WIDTH=90%><TR><TD>\n";

    print "<FONT SIZE=5>$nodeTitle</FONT>";
    print " [<A HREF=\"$scriptURL?action=editNode&nodeID=$nodeID\">" . 
        "edit</A>]\n"; 
    print " [<A HREF=\"$scriptURL?action=addToHotLinks&nodeID=$nodeID\">" . 
        "hot link</A>]";

    print "<BR><BR>\n";

    foreach my $paragraph ( @nodeElements ) {
        # search for link start tags, like <13>, and replace them
        # with HTML links to show the node (example:  show node 13)
        $paragraph =~ 
            s/<(\d+)>/<A HREF="$scriptURL?action=showNode&nodeID=$1">/g;
            #s/(<\d+>)/test/;

        # search for link end tags, like </13>, and replace them
        # with HTML link end tags, </A>
        $paragraph =~ 
            s/(<\/\d+>)/<\/A>/g;

        print "$paragraph<BR><BR>\n";        
    }

    print "</TD></TR></TABLE>\n";
    
    
    print "</TD>\n";
    

    print "<TD VALIGN=TOP WIDTH=25%>\n";

    printLinkTable( $nodeID, 0 );
    
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
            print "<TD VALIGN=MIDDLE>" .
                "<A HREF=\"$scriptURL?action=showNode&nodeID=$id\">".
                "$title</A></TD></TR>\n";
            $linkNumber++;
            
        }
        print "</TABLE>\n";

        print "<INPUT TYPE=\"submit\" VALUE=\"remove marked\">\n";
        print "</FORM>\n";
    }
    
}



##
# Gets the nodes linked from a node.
#
# @param0 the node ID to get links for.
#
# @return a list of linked node IDs.
#
# Example:
# my @linkedIDs = getNodeLinks( 13 );
##
sub getNodeLinks {
    my $nodeID = $_[0];
    
    my $linksText = readFileValue( "$dataDirectory/nodes/$nodeID.links" );
    
    # split by lines
    my @linkIDs = split( /\n/, $linksText );

    my @untaintedIDs = ();

    foreach my $id ( @linkIDs ) {
        #untaint
        ( $id ) = ( $id =~ /(\d+)/ );
        
        push( @untaintedIDs, $id );
    }

    return @untaintedIDs;
}



##
# Gets the nodes on th hot links list.
#
# @return a list of linked node IDs.
#
# Example:
# my @linkedIDs = getHotLinks( 13 );
##
sub getHotLinks {
    my $linksText = readFileValue( "$dataDirectory/hot.links" );
    
    # split by lines
    my @linkIDs = split( /\n/, $linksText );

    my @untaintedIDs = ();

    foreach my $id ( @linkIDs ) {
        #untaint
        ( $id ) = ( $id =~ /(\d+)/ );
        
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
            print "<TD VALIGN=MIDDLE>" .
                "<A HREF=\"$scriptURL?action=showNode&nodeID=$id\">" .
                "$title</A></TD></TR>\n";
            
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
    
    print "<TABLE WIDTH=100% CELLPADDING=5 CELLSPACING=0 BORDER=0>" .
        "<TR><TD BGCOLOR=#C0C0C0>";
    #print "test<BR>";
    print "<TABLE><TR><TD><FONT SIZE=7>silk</FONT></TD>\n";
    print "<TD>-- <A HREF=\"$scriptURL\">new node</A> --</TD></TR></TABLE>\n";
    print "</TD></TR></TABLE>\n";
#    print "<HR>\n";

}



##
# Prints the HTML footer for a page.
##
sub printPageFooter {
    print"</BODY></HTML>";
}



##
# Gets the title of a node.
#
# @param0 the node ID.
#
# @return the node's title.
#
# Example:
# my $title = getNodeTitle( "13" );
##
sub getNodeTitle {
    my $nodeID = $_[0];

    my $nodeText = readFileValue( "$dataDirectory/nodes/$nodeID.txt" );

    # split into paragraphs
    my @nodeElements = split( /\n\n/, $nodeText );

    my $nodeTitle = shift( @nodeElements );
    
    return $nodeTitle;
}



sub setupDataDirectory {
    
    if( not -e "$dataDirectory/nodes" ) {
        makeDirectory( "$dataDirectory/nodes", oct( "0777" ) );
    }
    
    if( not -e "$dataDirectory/hot.links" ) {
        writeFile( "$dataDirectory/hot.links", "" );
    }
    if( not -e "$dataDirectory/nextNodeID" ) {
        writeFile( "$dataDirectory/nextNodeID", "0" );
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

