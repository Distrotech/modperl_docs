#!/usr/local/bin/perl -w
use strict;
use Storable 'nstore';

=head1 NAME  

make.pl -- program to generate data needed for searching

=head1 Description

make.pl uses input contained within that defines "sections" of the
site based on path names.  These name can then be used when searching
with swish to limit searches to just these areas of the site.

When indexing the site with swish-e each file is taged with meta data
that indicates which section or sections it belongs to.

The input format is described in the source of this file.

make.pl creates two ouptut files:

=over 4

=item search_options

A template toolkit include file for defining an array of section names
and a hash that maps the section names to nice descriptions.  This
data is used to create the select box on the side bar during site
generation (by running bin/build).

It also creates a hash to use in a TT plugin to map the file's path
while running bin/build into section IDs.

=item checkboxes.storable

A perl data structure used for use in the F<search.cgi> script to
generate the nested checkboxes for the advanced search feature.  This
allows selecting more than one area of the site at a time.

This file is saved using the Storable perl module, and is read in by
the search script (F<swish.cgi>) configuration parameter file
F<.swishcgi.conf> and made available to Template-Toolkit when
F<swish.cgi> is running.

This file is also read when indexing with swish-e (see
F<SwishSpiderConfig.pl>) and is used to map path names into section
names.

=back

Running this program is described in the F<README> file contained in
the F<src/search> directory of the mod_perl site distribution.


=cut


# This must match up with .swishcgi.conf setting and
# SwishSpiderConfig.pl
my $CHECKBOX_DATA = 'checkboxes.storable';

# This is used for all pages -- it's the array and has for the sidebar search
# It contains an array parsable by Template Toolkit.
my $SEARCH_OPTIONS = 'search_options';


# Stas added tree display - Apr 15, 2002
# Rewritten May 23, 2000 at Stas' request to centralize the input data
# in one place
# syntax (amount of spaces doesn't matter):
# indent, path, title, optional short title (for drop down list)
#

my $items = <<ITEMS;
    0, start,              What's mod_perl?
    0, outstanding,        Technologie Extraordinaire, Stories
    0, download,           Download,                   Download
    0, docs,               Documentation,              All Docs
    1,   docs/1.0,         mod_perl 1.0 Docs,          1.0 Docs
    2,     docs/1.0/guide, Guide (1.0)
    2,     docs/1.0/win32, Win32 (1.0)
    2,     docs/1.0/api,   API (1.0)
    1,   docs/2.0,         mod_perl 2.0 Docs,          2.0 Docs
    2,     docs/2.0/user,  User (2.0)
    2,     docs/2.0/devel, Developer (2.0)
    2,     docs/2.0/api,   API (2.0)
    1,   docs/general,     General Docs
    1,   docs/tutorials,   Tutorials
    1,   docs/offsite,     OffSite Docs
    0, help,               Getting Help
    0, maillist,           Mailing Lists
    0, products,           Products
    0, contribute,         Contribute
    0, about,              About mod_perl
ITEMS



    # Split the above items out into a hash.

    my $section_id = 'SecA';

    my @items_flat = map {
             s/^\s+//;
             s/\s+$//;
             $_ = $section_id++ . ", $_";
             my %h;
             @h{qw/section indent path label short/} = split m!\s*,\s*!;

             $h{short} ||= ( $h{label} || 'missing description' );

             \%h
        } split /\n/, $items;



    # Build the data parsable by Template-Toolkit
    
    my $array_values = join "\n", map { ' ' x (( $_->{indent}+2 ) * 4) . qq["$_->{section}"] }  @items_flat;

    my $hash_values  = join "\n", map {
        my $dots = '..' x  $_->{indent};
        my $spaces = ' ' x (( $_->{indent}+2 ) * 4);
        qq[$spaces"$_->{section}" => "$dots$_->{short}" ]
    } @items_flat;

    my $path_map  = join "\n", map {
        qq[        { path => "^$_->{path}", section => "$_->{section}" } ]
    } sort { length $b->{path} <=> length $a->{path} } @items_flat;
    
        


    my $check_box_array = build_array( \@items_flat );

#use Data::Dumper;
#print Dumper $check_box_array;

    nstore( $check_box_array, $CHECKBOX_DATA );  # store for swish.cgi

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

    search_path_map = [
$path_map
    ]
-%]
    
EOF

    close FH || warn "Failed to close '$SEARCH_OPTIONS': $!";

    warn "Built search data structures\n";
    


#==============================================================================
# Subroutine that builds the data structure expected by template toolkit
# TT uses values .section, .label, and .subs.  See search.tt for example
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

