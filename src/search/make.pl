#!/usr/local/bin/perl -w
use strict;
use Storable;

# This must match up with .swishcgi.conf setting
my $CHECKBOX_DATA = 'checkboxes.storable';

# This is used for all pages -- it's the array and has for the sidebar search
my $SEARCH_OPTIONS = 'search_options';


# Stas added tree display - Apr 15, 2002
# Rewritten May 23, 2000 at Stas' request to centralize the input data in one place
# syntax (amount of spaces doesn't matter):
# indent, path, title, optional short title (for drop down list)
#


my $items = <<ITEMS;
    0, outstanding, Technologie Extraordinaire, Stories
    0, download,    Download, Download
    0, docs,        Documentation, All Docs
    1,   docs/1.0, mod_perl 1.0 Docs, 1.0 Docs
    2,     docs/1.0/guide, Guide,
    2,     docs/1.0/win32, Win32
    2,     docs/1.0/api,   API
    1,   docs/2.0, mod_perl 2.0 Docs, 2.0 Docs
    2,     docs/2.0/user,  User
    2,     docs/2.0/devel, Developer
    2,     docs/2.0/api,   API
    1,   docs/general,      General Docs
    1,   docs/tutorials,    Tutorials
    1,   docs/offsite,      OffSite Docs
    0, help,       Getting Help
    0, maillist,  Mailing Lists
    0, products,   Products
    0, contribute, Contribute
ITEMS



    my @items_flat = map {
             s/^\s+//;
             s/\s+$//;
             my %h;
             @h{qw/indent value label short/} = split m!\s*,\s*!;

             $h{short} ||= ( $h{label} || 'missing description' );

             \%h
        } split /\n/, $items;


    my $array_values = join "\n", map { ' ' x (( $_->{indent}+2 ) * 4) . qq["$_->{value}"] }  @items_flat;
    my $hash_values  = join "\n", map {
        my $dots = '..' x  $_->{indent};
        my $spaces = ' ' x (( $_->{indent}+2 ) * 4);
        qq[$spaces"$_->{value}" => "$dots$_->{short}" ]
    } @items_flat;
        
    my $check_box_array = build_array( \@items_flat );

#use Data::Dumper;                
#print Dumper $check_box_array;

    store( $check_box_array, $CHECKBOX_DATA );  # store for swish.cgi

    # Now write out the search_options
    open FH, ">$SEARCH_OPTIONS" or die "Failed to open '$SEARCH_OPTIONS': $!";

    my $now = scalar localtime;
    
    print FH <<EOF;
[%-
#--------------------------------------------------------------------------------------
# *** Automatically generated file.  Do not edit.  Modify $0 instead! ***
#    File: '$SEARCH_OPTIONS'
#     Use: generating the sidebar select options for searching
# Created: $now
#--------------------------------------------------------------------------------------

    search_areas = [
        ""
$array_values
    ]

    search_labels = {
        ""          => 'Whole Site'
$hash_values        
    }
-%]
EOF

    close FH || warn "Failed to close '$SEARCH_OPTIONS': $!";

    warn "Built search data structures\n";
    


#==============================================================================
# Subroutine that builds the data structure expected by template toolkit
# TT uses values .value, .label, and .subs.  See search.tt for example
#
#
#
sub build_array {
    my ( $items ) = @_;

    my $indent = $items->[0]{indent};

    my @array;

    while ( @$items ) {  # more left in array?

        if ( $items->[0]{indent} == $indent ) {      # this is the level we are processing
            push @array, shift @$items;

        } elsif ( $items->[0]{indent} < $indent ) {  # all done with this level, so just return
            return \@array;

        } else {                                        # found an indented section
            $array[-1]{subs} = build_array( $items );
        }
    }

    return \@array;
}

