#!/usr/local/bin/perl -w
use strict;

=pod

To give some background.

when you search with swish you do something like:

  ./swish-e -w swishdefault=foo

that says: search the field "swishdefault" for the word foo.  swishdefault
is the default "metaname".  When indexing, say html, swish indexes the body
text AND the title as swishdefault.

So, a document will match if "foo" is found in the title or in the body when searching
the swishdefault metaname.  This is why in the sample code below supplies both the title
and description to the highlighting code.

The other part to swish is "properties".  A document property is something like
the path name, title, or last modified date.  Some bit of data that can be returned
with search results.  So, when you do a search for "foo" swish will
return a list of documents, and for each document it will list properties.

Since properties and metanames may or may not be related, in the "config" below you see a hash that maps
one or more properties to metanames.

Note, here's a search for "apache" limiting to four results.

> ./swish-e -w apache -m 4
# SWISH format: 2.1-dev-24
# Search words: apache
# Number of hits: 120
# Search time: 0.001 seconds
# Run time: 0.006 seconds
1000 /usr/local/apache/htdocs/manual/misc/FAQ.html "Apache Server Frequently Asked Questions" 107221
973 /usr/local/apache/htdocs/manual/windows.html "Using Apache with Microsoft Windows" 21664
953 /usr/local/apache/htdocs/manual/mod/core.html "Apache Core Features" 121406
933 /usr/local/apache/htdocs/manual/netware.html "Using Apache with Novell NetWare 5" 11345

That's returning the properties rank, path, title (called swishtitle), document size by default.

Swish can also store as a property the words extracted while indexing and return that
text in the search results.  This property is called "swishdescription".  It's a lot
faster for swish to return this in results than to go and fetch the source document by path
and then extract out the content.


=cut 


# here's the emulated results from swish placed in the "properties" hash

show() for ( 1..15 );

sub show {

    my %properties = (
        swishtitle          => 'Apache module mod_foobar',
        swishdescription    => Content::content(),
    );

    # emulate a result object

    my $result = result->new;



    my $hl = PhraseHighlight->new($result, 'swishdefault' );
    $hl->highlight( \%properties );
    use Text::Wrap qw(wrap);
    print "\nTitle: $properties{ swishtitle }\n\nDescription:\n",
          wrap(' ',' ',$properties{ swishdescription }),"\n";

}          






#===============================================================
    
package result;
use strict;

use Carp;



sub new {
    bless {
        config => {
            description_prop => 'swishdescription',

            highlight       => {
                package         => 'PhraseHighlight',
                show_words      => 10,    # Number of swish words words to show around highlighted word
                max_words       => 100,   # If no words are found to highlighted then show this many words
                occurrences     => 6,     # Limit number of occurrences of highlighted words
                highlight_on    => '<<on>>',
                highlight_off   => '<</off>>',
                meta_to_prop_map => {   # this maps search metatags to display properties
                    swishdefault    => [ qw/swishtitle swishdescription/ ],
                    swishtitle      => [ qw/swishtitle/ ],
                    swishdocpath    => [ qw/swishdocpath/ ],
                },
            },
        },
    }, shift;

}


sub header {
   my ( $self, $value ) = @_;

   my %values = (
        wordcharacters      => 'abcdefghijklmnopqrstuvwxyz-,.',
        ignorefirstchar     => '.-,',
        ignorelastchar      => '.-,',
        'stemming applied'  => 0,
        stopwords           => 'and the is for',
   );

   return $values{$value} || '';
}

sub config {
    my ($self, $setting, $value ) = @_;

    croak "Failed to pass 'config' a setting" unless $setting;

    my $cur = $self->{config}{$setting} if exists $self->{config}{$setting};

    $self->{config}{$setting} = $value if $value;

    return $cur;
}

# This emulates the parsing of the query passed to swish-e

sub extract_query_match {
    return {
        text => {                                ## can be text or url "layer"
            swishdefault    => [                 ## metaname searched
                [qw/directive not compatible/],  ## phrase made up of three words (not stopword missing)
                [qw/ foobar /],                  ## phrase of one word
                [qw/ des* /],                  ## wildcard search
            ],
        },
     };
}
    


#=======================================================================
#  Phrase Highlighting Code
#
#  copyright 2001 - Bill Moseley moseley@hank.org
#
#    $Id: PhraseTest.pm,v 1.1 2002/01/30 06:35:00 stas Exp $
#=======================================================================
package PhraseHighlight;
use strict;

use constant DEBUG_HIGHLIGHT => 0;

sub new {
    my ( $class, $results, $metaname ) = @_;

    my $self = bless {
        results => $results,  # just in case we need a method
        settings=> $results->config('highlight'),
        metaname=> $metaname,
    }, $class;


    # parse out the query into words
    my $query = $results->extract_query_match;


    # Do words exist for this layer (all text at this time) and metaname?
    # This is a reference to an array of phrases and words

    $self->{description_prop} = $results->config('description_prop') || '';



    if ( $results->header('stemming applied') =~ /^(?:1|yes)$/i ) {
        eval { require SWISH::Stemmer };
        if ( $@ ) {
            $results->errstr('Stemmed index needs Stemmer.pm to highlight: ' . $@);
        } else {
            $self->{stemmer_function} = \&SWISH::Stemmer::SwishStem;
        }
    }



    my %stopwords =  map { $_, 1 } split /\s+/, $results->header('stopwords');
    $self->{stopwords} = \%stopwords;


    if ( $query && exists $query->{text}{$metaname} ) {
        $self->{query} = $query->{text}{$metaname};
        $self->set_match_regexp;
    }

    return $self;
}

sub highlight {
    my ( $self, $properties ) = @_;

    return unless $self->{query};

    my $phrase_array = $self->{query};

    my $settings = $self->{settings};
    my $metaname = $self->{metaname};

    # Do we care about this meta?
    return unless exists $settings->{meta_to_prop_map}{$metaname};

    # Get the related properties
    my @props = @{ $settings->{meta_to_prop_map}{$metaname} };

    my %checked;

    for ( @props ) {
        if ( $properties->{$_} ) {
            $checked{$_}++;
            $self->highlight_text( \$properties->{$_}, $phrase_array );
        }
    }


    # Truncate the description, if not processed.
    my $description = $self->{description_prop};
    if ( $description && !$checked{ $description } && $properties->{$description} ) {
        my $max_words = $settings->{max_words} || 100;
        my @words = split /\s+/, $properties->{$description};
        if ( @words > $max_words ) {
            $properties->{$description} = join ' ', @words[0..$max_words], '<b>...</b>';
        }
    }

}



#==========================================================================
#

sub highlight_text {

    my ( $self, $text_ref, $phrase_array ) = @_;

    my $wc_regexp = $self->{wc_regexp};
    my $extract_regexp = $self->{extract_regexp};


    my $last = 0;

    my $settings = $self->{settings};

    my $Show_Words = $settings->{show_words} || 10;
    my $Occurrences = $settings->{occurrences} || 5;




    my $on_flag  = 'sw' . time . 'on';
    my $off_flag = 'sw' . time . 'off';


    my $stemmer_function = $self->{stemmer_function};

    # Should really call unescapeHTML(), but then would need to escape <b> from escaping.

    # Split into words.  For speed, should work on a stream method.
    my @words;
    $self->split_by_wordchars( \@words, $text_ref );


    return 'No Content saved: Check StoreDescription setting' unless @words;

    my @flags;  # This marks where to start and stop display.
    $flags[$#words] = 0;  # Extend array.

    my $occurrences = $Occurrences ;


    my $word_pos = $words[0] eq '' ? 2 : 0;  # Start depends on if first word was wordcharacters or not

    my @phrases = @{ $self->{query} };

    # Remember, that the swish words are every other in @words.

    WORD:
    while ( $Show_Words && $word_pos * 2 < @words ) {

        PHRASE:
        foreach my $phrase ( @phrases ) {

            print STDERR "  Search phrase '@$phrase'\n" if DEBUG_HIGHLIGHT;
            next PHRASE if ($word_pos + @$phrase -1) * 2 > @words;  # phrase is longer than what's left
            

            my $end_pos = 0;  # end offset of the current phrase

            # now compare all the words in the phrase

            my ( $begin, $word, $end );
            
            for my $match_word ( @$phrase ) {

                my $cur_word = $words[ ($word_pos + $end_pos) * 2 ];
                unless ( $cur_word =~ /$extract_regexp/ ) {

                    my $idx = ($word_pos + $end_pos) * 2;
                    my ( $s, $e ) = ( $idx - 10, $idx + 10 );
                    $s = 0 if $s < 0;
                    $e = @words-1 if $e >= @words;
                   
                
                    warn  "Failed to parse IgnoreFirst/Last from word '"
                    . (defined $cur_word ? $cur_word : '*undef')
                    . "' (index: $idx) word_pos:$word_pos end_pos:$end_pos total:"
                    . scalar @words
                    . "\n-search pharse words-\n"
                    . join( "\n", map { "$_ '$phrase->[$_]'" } 0..@$phrase -1 )
                    . "\n-Words-\n"
                    . join( "\n", map { "$_ '$words[$_]'" . ($_ == $idx ? ' <<< this word' : '') } $s..$e )
                    . "\n";

                    next PHRASE;
                }




                # Strip ignorefirst and ignorelast
                ( $begin, $word, $end ) = ( $1, $2, $3 );  # this is a waste, as it can operate on the same word over and over

                my $check_word = lc $word;

                if ( $end_pos && exists $self->{stopwords}{$check_word} ) {
                    $end_pos++;
                    print STDERR " Found stopword '$check_word' in the middle of phrase - * MATCH *\n" if DEBUG_HIGHLIGHT;
                    redo if  ( $word_pos + $end_pos ) * 2 < @words;  # go on to check this match word with the next word.

                    # No more words to match with, so go on to next pharse.
                    next PHRASE;
                }

                if ( $stemmer_function ) {
                    my $w = $stemmer_function->($check_word);
                    $check_word = $w if $w;
                }



                print STDERR "     comparing source # (word:$word_pos offset:$end_pos) '$check_word' == '$match_word'\n" if DEBUG_HIGHLIGHT;
    
                if ( substr( $match_word, -1 ) eq '*' ) {
                    next PHRASE if index( $check_word, substr($match_word, 0, length( $match_word ) - 1) ) != 0;

                } else {
                    next PHRASE if $check_word ne $match_word;
                }


                print STDERR "      *** Word Matched '$check_word' *** \n" if DEBUG_HIGHLIGHT;
                $end_pos++;  
            }

            print STDERR "      *** PHRASE MATCHED (word:$word_pos offset:$end_pos) *** \n" if DEBUG_HIGHLIGHT;


            # We are currently at the end word, so it's easy to set that highlight

            $end_pos--;

            if ( !$end_pos ) { # only one word
                $words[$word_pos * 2] = "$begin$on_flag$word$off_flag$end";
            } else {
                $words[($word_pos + $end_pos) * 2 ] = "$begin$word$off_flag$end";

                #Now, reload first word of match
                $words[$word_pos * 2] =~ /$extract_regexp/ or die "2 Why didn't '$words[$word_pos]' =~ /$extract_regexp/?";
                # Strip ignorefirst and ignorelast
                ( $begin, $word, $end ) = ( $1, $2, $3 );  # probably should cache this!
                $words[$word_pos * 2] = "$begin$on_flag$word$end";
            }


            # Now, flag the words around to be shown
            my $start = ($word_pos - $Show_Words + 1) * 2;
            my $stop   = ($word_pos + $end_pos + $Show_Words - 2) * 2;
            if ( $start < 0 ) {
                $stop = $stop - $start;
                $start = 0;
            }
            
            $stop = $#words if $stop > $#words;

            $flags[$_]++ for $start .. $stop;


            # All done, and mark where to stop looking
            if ( $occurrences-- <= 0 ) {
                $last = $end;
                last WORD;
            }


            # Now reset $word_pos to word following
            $word_pos += $end_pos; # continue will still be executed
            next WORD;
        }
    } continue {
        $word_pos ++;
    }



    my @output;
    $self->build_highlighted_text( \@output, \@words, \@flags, $last );


    $self->join_words( \@output, $text_ref );


    $self->escape_entities( $text_ref );
    $self->substitue_highlight( $text_ref, $on_flag, $off_flag );

    
    # $$text_ref = join '', @words;  # interesting that this seems reasonably faster


}

#====================================================================
#  Split the source text into swish and non-swish words

sub split_by_wordchars {
    my ( $self, $words, $text_ref ) = @_;
    my $wc_regexp = $self->{wc_regexp};
    
    @$words = split /$wc_regexp/, $$text_ref;
}


#=======================================================================
#  Put all the words together for display
#
sub build_highlighted_text {
    my ( $self, $output, $words, $flags, $last ) = @_;
    
    my $dotdotdot = ' ... ';

    my $printing;
    my $first = 1;
    my $some_printed;

    my $settings = $self->{settings};
    my $Show_Words = $settings->{show_words} || 10;
    

    if ( $Show_Words && @$words > 50 ) {  # don't limit context if a small number of words
        
        for my $i ( 0 ..$#$words ) {


            if ( $last && $i >= $last && $i < $#$words ) {
                push @$output, $dotdotdot;
                last;
            }

            if ( $flags->[$i] ) {

                push @$output, $dotdotdot if !$printing++ && !$first;
                push @$output, $words->[$i];
                $some_printed++;

            } else {
                $printing = 0;
            }

        $first = 0;

        
        }
    }



    if ( !$some_printed ) {
        my $Max_Words = $settings->{max_words} || 100;

        for my $i ( 0 .. $Max_Words ) {
            if ( $i > $#$words ) {
                $printing++;
                last;
            }
            push @$output, $words->[$i];
        }
    }
        
    push @$output, $dotdotdot if !$printing;
}    

#==================================================================
#
sub join_words {
    my ( $self, $output, $text_ref ) = @_;
    
    $$text_ref = join '', @$output;
}

sub escape_entities {
    my ( $self, $text_ref ) = @_;

    my %entities = (
        '&' => '&amp;',
        '>' => '&gt;',
        '<' => '&lt;',
        '"' => '&quot;',
    );
    $$text_ref =~ s/([&"<>])/$entities{$1}/ge;
}

#========================================================
# replace the highlight codes

sub substitue_highlight {
    my ( $self, $text_ref, $on_flag, $off_flag ) = @_;

    my $settings = $self->{settings};
    my $On = $settings->{highlight_on} || '<b>';
    my $Off = $settings->{highlight_off} || '</b>';

    my %highlight = (
        $on_flag => $On,
        $off_flag => $Off,
    );
        
    $$text_ref =~ s/($on_flag|$off_flag)/$highlight{$1}/ge;
}

#============================================
# Returns compiled regular expressions for matching
#
#

sub set_match_regexp {
    my $self = shift;

    my $results = $self->{results};


    my $wc = $results->header('wordcharacters');
    my $ignoref = $results->header('ignorefirstchar');
    my $ignorel = $results->header('ignorelastchar');


    $wc = quotemeta $wc;

    #Convert query into regular expressions


    for ( $ignoref, $ignorel ) {
        if ( $_ ) {
            $_ = quotemeta;
            $_ = "([$_]*)";
        } else {
            $_ = '()';
        }
    }


    $wc .= 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';  # Warning: dependent on tolower used while indexing


    # Now, wait a minute.  Look at this more, as I'd hope that making a
    # qr// go out of scope would release the compiled pattern.

    if ( $ENV{MOD_PERL} ) {
        $self->{wc_regexp}      = qr/([^$wc]+)/;                     # regexp for splitting into swish-words
        $self->{extract_regexp} = qr/^$ignoref([$wc]+?)$ignorel$/i;  # regexp for extracting out the words to compare

     } else {
        $self->{wc_regexp}      = qr/([^$wc]+)/o;                    # regexp for splitting into swish-words
        $self->{extract_regexp} = qr/^$ignoref([$wc]+?)$ignorel$/oi;  # regexp for extracting out the words to compare
     }
}



package Content;

sub content {

    my $content = <<EOF;
Apache HTTP Server Version 1.3 Module mod_foobar Add this file as a link in mod/index.html
This module is contained in the mod_foobar.c file, and is/is not compiled in by default.
It provides for the foobar feature. Any document with the mime type foo/bar will be processed by this module.
Add the magic mime type to the list in magic_types.html Summary General module documentation here.
Directives ADirective Add these directives to the list in directives.html
ADirective directive Syntax: ADirective some args Default:
ADirective default value Context: context-list context-list is where this directive can appear;
allowed: server config, virtual host, directory, .htaccess Override: override required if the
directive is allowed in .htaccess files; the AllowOverride option that allows the directive.
Status: status Core if in core apache, Base if in one of the standard modules,
Extension if in an extension module (not compiled in by default) or
Experimental Module: mod_foobar Compatibility: compatibility notes Describe any compatibility issues,
such as "Only available in Apache 1.2 or later," or "The Apache syntax for this directive is not
compatible with the NCSA directive of the same name." The ADirective directive does something.
Apache HTTP Server Version 1.3
EOF

    $content =~ s/\n/ /g;
    return $content;
}



