package tokenWord::userWorkspace;

#
# Modification History
#
# 2003-January-7   Jason Rohrer
# Created.
#
# 2003-January-8   Jason Rohrer
# Added function for extracting abstract quotes.
#


use tokenWord::common;
use tokenWord::chunkManager;
use tokenWord::documentManager;
use tokenWord::quoteClipboard;



##
# Submits an abstract document (text and quote tags).
#
# @param0 the username.
# @param1 the text of the document.
#
# @return the id of the new document.
#
# Example:
# my $docID = submitAbstractDocument( "jj55", "I am quoting here: <q 10>" );
##
sub submitAbstractDocument {
    ( my $username, my $docText ) = @_;
    
    # replace < and > with @< and >@
    $docText =~ s/</@</;
    $docText =~ s/>/>@/;
    
    my @docSections = split( /@/, $docText );

    my @docRegions = ();

    # for tracking locations of quotes in this document
    my $netDocOffset = 0;
    my @quotesToNote = ();


    foreach my $section ( @docSections ) {
        if( $section =~ m/<\s*q\s*\d+\s*>/ ) {
            # a quote
            
            #extract the quote number
            $section =~ s/[<q>]//g;
            $section =~ s/\s//;

            my $quoteNumber = $section;
            
            # build a < chunkLocator; docLocator > style locator for each 
            # chunk in this quote, where the docLocator points to the
            # document being quoted now

            my @docRegion = 
                tokenWord::quoteClipboard::getQuoteRegion( $username,  
                                                           $quoteNumber );
            
            # add this quote to our list of quotes to note

            my $quoteLength = $docRegion[3];
            
            my $quotedDocRegionString = join( ",", @docRegion );
            my $quotingDocRegionString = 
                "$username, DOC_ID, $netDocOffset, $quoteLength";

            push( @quotesToNote, 
                  "< $quotedDocRegionString > | < $quotingDocRegionString >" );

            $netDocOffset += $quoteLength;



            my @quoteChunks =
                tokenWord::documentManager::getRegionChunks( @docRegion );
            
            my $docOwner = $docRegion[0];
            my $docNumber = $docRegion[1];
            my $currentDocOffset = $docRegion[2];

            foreach $chunk ( @quoteChunks ) {

                my @chunkElements = extractRegionComponents( $chunk );
                
                my $chunkLength = $chunkElements[3];
                
                my $chunkLocator = join( ", ", @chunkElements );

                my $docLocator = join( ", ", ( $docOwner, $docNumber,
                                               $currentDocOffset ) );

                my $fullChunkLocator =
                    join( "; ", ( $chunkLocator, $docLocator ) );
                
                push( @docRegions, "< $fullChunkLocator >" );
                
                $currentDocOffset += $chunkLength;
            }

        }
        else {
            # a new chunk

            my $chunkID = 
              tokenWord::chunkManager::addChunk( $username, 
                                                 $section );
            my $chunkLength = length( $section );

            my $chunkString = "< $username, $chunkID, 0, $chunkLength >";
            
            push( @docRegions, $chunkString );

            $netDocOffset += $chunkLength;
        }
        
    }

    my $concreteDocumentString = join( "\n", @docRegions );

    my $newDocID = tokenWord::documentManager::addDocument( $username, 
                                                    $concreteDocumentString );
    
    # note our quotes in the document manager

    foreach my $quoteString ( @quotesToNote ) {

        my @quoteParts = split( /\s*\|\s*/, $quoteString );
        
        # insert new doc ID into placeholder
        $quoteParts[1] =~ s/DOC_ID/$newDocID/;
        
        tokenWord::documentManager::noteQuote( @quoteParts );
    }
    

    return $newDocID;
}



##
# Extracts a quoted region from abstract document (text and quote tag pair).
#
# @param0 the quoting user.
# @param1 the quoted user.
# @param3 the quoted documentID.
# @param4 the abstract document string.
#
# @return the id of the new quote.
#
# Example:
# my $quoteID = extractAbstractQuote( "jj55", "jdg1", 10, 
#                                     "This is a <q>test document</q>." );
##
sub extractAbstractQuote {
    ( my $quotingUser, my $quotedUser, my $docID, my $docText ) = @_;
    
    
    # split around quote tags
    my @splitDocument = split( /<\s*\/?\s*q\s*>/, $docText );

    my $quoteOffset = length( $splitDocument[0] );
    my $quoteLength = length( $splitDocument[1] );
    
    tokenWord::quoteClipboard::addQuote( $quotingUser,
                                         $quotedUser,
                                         $docID,
                                         $quoteOffset,
                                         $quoteLength );
}



##
# Purchases all chunks in a document as necessary.
#
# @param0 the purchasing user.
# @param1 the user owning the document.
# @param3 the document id.
#
# Example:
# purchaseDocument( "jj55", "jdg1", 10 );
##
sub purchaseDocument {
    ( my $purchasingUser, my $docOwner, my $docID ) = @_;

    my $purchasedDirName = 
        "$dataDirectory/users/$purchasingUser/purchasedRegions";

    my @docChunks = 
        tokenWord::documentManager::getAllChunks( $docOwner, $docID );
    
    foreach my $chunk ( @docChunks ) {
        my @chunkElements = extractRegionComponents( $chunk );

        my $chunkOwner = $chunkElements[0];
        
        if( $purchasingUser ne $chunkOwner ) {

            my $chunkID = $chunkElements[1];
            my $startOffset = $chunkElements[2];
            my $length = $chunkElements[3];

            my $purchasedChunkFile = "$purchasedDirName/$chunkOwner/$chunkID";

            if( not -e "$purchasedDirName/$chunkOwner" ) {
                # make purchased dir
                mkdir( "$purchasedDirName/$chunkOwner", oct( "0777" ) );
            
                writeFile( $purchasedChunkFile,
                       "< $chunkOwner, $chunkID, $startOffset, $length >\n" );
                
                tokenWord::userManager::transferTokens( $purchasingUser,
                                                        $chunkOwner,
                                                        $length );
            }
            else {
                # dir exists for that owner
                if( not -e $purchasedChunkFile ) {
                    # make a file
                    writeFile( $purchasedChunkFile,
                       "< $chunkOwner, $chunkID, $startOffset, $length >\n" );
                    
                    tokenWord::userManager::transferTokens( $purchasingUser,
                                                            $chunkOwner,
                                                            $length );
                }
                else {
                    # file already exists for this chunk
                    my $chunkListString = 
                        readFileValue( $purchasedChunkFile ); 
                    
                    my @chunkList = split( /\n/, $chunkListString );
                    
                    my $chunkEmptied = 0;

                    foreach my $purchasedChunk ( @chunkList ) {
                        my @trimedChunks = 
                            trimRegion( $chunk, $purchasedChunk );
                    
                        if( $#trimedChunks == 0 ) {
                            # nothing left
                            # FIXME
                            $chunkEmptied = 1;
                            @chunkList = ();
                        }
                        elsif( $#trimmedChunks == 1 ) {
                            $chunk = $trimmedChunks[0];
                        }
                        elsif( $#trimmedChunks == 2 ) {
                            # continue processing first portion
                            $chunk = $trimmedChunks[0];
                            # add the excess to the end of our chunk list
                            push( @docChunks, $trimmedChunks[1] );
                        }
                    }
                    
                    if( not $chunkEmptied ) {
                        # we need to pay based on how much of the chunk
                        # we still need to purchase
                        my @chunkElements = extractRegionComponents( $chunk );
                        my $chunkLength = $chunkElements[3];
                    
                      tokenWord::userManager::transferTokens( $purchasingUser,
                                                              $chunkOwner,
                                                              $chunkLength );
                        # add the chunk to the end of our purchased file
                        addToFile( $purchasedChunkFile, "$chunk\n" );
                    }
                }
            }
        }
    }
}



##
# Gets whether two regions intersect.
#
# @param0 region A.
# @param1 region B.
#
# @return 1 if regions intersect, 0 otherwise.
#
# Example:
# my $hit = doRegionsIntersect( "<jj55, 10, 4, 32>", "<jj55, 10, 5, 10>" );
## 
sub doRegionsIntersect {
    ( my $regionAString, my $regionBString ) = @_;

    my @regionA = extractRegionComponents( $regionAString );
    my @regionB = extractRegionComponents( $regionBString );

    if( $regionA[0] ne $regionB[0] ) {
        return 0;
    }
    elsif( $regionA[1] ne $regionB[1] ) {
        return 0;
    }
    else {
        # same user and document

        my $startA = $regionA[2];
        my $startB = $regionB[2];
        my $lengthA = $regionA[3];
        my $lengthB = $regionB[3];
        
        # end is character *after* last character
        my $endA = $startA + $lengthA;
        my $endB = $startB + $lengthB;

        if( $endA <= $startB ) {
            return 0;
        }
        elsif( $endB <= $startA ) {
            return 0;
        }
        else {
            return 1;
        }
    }
}



##
# Trims one region to exclude intersection with another.
#
# @param0 region to trim.
# @param1 trimming region.
#
# @return the string representions of the trimmed region.
#
# Example:
# my @trimmed = trimRegion( "<jj55, 10, 4, 32>", "<jj55, 10, 5, 10>" );
## 
sub trimRegion {
    ( my $regionToTrimString, my $trimmingRegionString ) = @_;
    
    if( ! doRegionsIntersect( $regionToTrimString, $trimmingRegionString ) ) {
        # no intersection
        return ( $regionToTrimString );
    }
    
    # else an intersection

    my @regionA = extractRegionComponents( $regionToTrimString );
    my @regionB = extractRegionComponents( $trimmingRegionString );

    my $userA = $regionA[0];
    my $docA = $region[1];

    my $startA = $regionA[2];
    my $startB = $regionB[2];
    my $lengthA = $regionA[3];
    my $lengthB = $regionB[3];
        
    # end is character *after* last character
    my $endA = $startA + $lengthA;
    my $endB = $startB + $lengthB;

    if( $startA < $startB && $endB < $endA ) {
        # trim splits us into two regions
        my $firstLength = $startB - $startA;
        my $secondLength = $endA - $endB;
        return ( "< $userA, $docA, $startA, $firstLength >",
                 "< $userA, $docA, $endB, $secondLength >" );
    }
    
    if( $startA > $startB && $endB > $endA ) {
        # trim leaves nothing
        return ( );
    }

    if( $startA < $startB ) {
        # trim leaves only first portion of region A
        my $firstLength = $startB - $startA;
        return ( "< $userA, $docA, $startA, $firstLength >" );
    }

    if( $endB < $endA ) {
        my $secondLength = $endA - $endB;
        return ( "< $userA, $docA, $endB, $secondLength >" );
    }
}




# end of package
1;