# this is the modified default spider config file that comes with swish-e.
# Perldoc swish.cgi for docs on the format of this file
#
# a few custom callbacks are located after the @servers definition section
# these are used to split files into sections.

my $base_path = $ENV{MODPERL_SITE} || die "must set \$ENV{MODPERL_SITE}";

$base_path =~ s[/$][];

# Used to fetch the available "sections" 
my $CHECKBOX_DATA = 'checkboxes.storable';


@servers = (
    {
        base_url        => "$base_path/index.html",

        # Debugging -- see perldoc spider.pl

        #max_depth => 1,
        #debug => DEBUG_HEADERS,
        #debug => DEBUG_URL|DEBUG_SKIPPED|DEBUG_INFO,
        #debug => DEBUG_LINKS,

        keep_alive      => 1,         # enable keep alives requests
        email           => 'swish@domain.invalid',

        use_md5         => 1,    # catch duplicates ( / and /index.html )

        delay_min       => .0001,


        # Ignore images files
        test_url => sub { return $_[0]->path !~ /\.(?:gif|jpeg|.png|.gz)$/i },

        # Only index text/html
        test_response   => sub { return $_[2]->content_type =~ m[text/html] },

        # split content - comment out to disable splitting
        filter_content  => \&split_page,

        # optionally validate external links
        validate_links  => $ENV{VALIDATE_LINKS} || 0,
    },

);

use HTML::TreeBuilder;
use HTML::Element;

sub split_page {

    my %params;
    @params{ qw/ uri server response content / } = @_;
    $params{found} = 0;

    my $tree = HTML::TreeBuilder->new;
    $tree->store_comments(1);

    $tree->parse( ${$params{content}} );  # Why not allow a scalar ref?
    $tree->eof;

    $params{page_length} = length ${$params{content}};


    # Find the <head> section for use in all split pages
    my $head = $tree->look_down( '_tag', 'head' );

    # Now create a new "document" for each
    create_page( $head->clone, $_->clone, \%params )
        for $tree->look_down( '_tag', 'div', 'class', 'index-section' );


    ## If a page doesn't have an "index_section" then it's probably a table of contents (index.html)
    ## so don't index it.
    $tree->delete;
    return 0;

    # old code below to index pages that don't have sections defined.


    # Indexed the page in sections, just return
    return 0 if $params{found};

    

    # No sections found, so index the entire page (probably index.html)

    # Stip base_path
    #my $url = $params{uri}->as_string;
    #$url =~ s/^$base_path//;

    my $new_content = $tree->as_HTML(undef,"\t");
    output_content( $params{server}, $params{content},
                    $params{uri}, $params{response} );


    $tree->delete;

    return 0; # don't index
}

sub create_page {
    my ( $head, $section, $params ) = @_;

    my $uri = $params->{uri};

    # Grab the first <a name="..."> tag that indicates this section.
    # and adjust the path

    if ( my $name = $section->look_down( '_tag', 'a', sub { defined($_[0]->attr('name')) } ) ) {
        $uri->fragment( $name->attr('name') );
    }
        


    # Now grab the first <a href="..">description</a> tag
    if ( my $link = $section->look_down( '_tag', 'a', sub { defined($_[0]->attr('href')) } ) ) {

        my $description = $link->as_text;

        if ( $description ) {

            # Modify or create the title
    
            my $title = $head->look_down('_tag', 'title');

            if ( $title ) {
                $title->push_content( ": $description" );

            } else { # Create a new title
            
                my $title = HTML::Element->new('title');
                $title->push_content( $description );
                $head->push_content( $title );
            }
        }
    }





    # Extract out part of the path to use for limiting searches to parts of the document tree.


    if ( $uri =~ m!$base_path/(.+)$! ) {
        my $path = $1;

        if ( my $sections = map_path_to_sections( $path ) ) {
            my $meta = HTML::Element->new('meta', name=> 'section', content => $sections);
            $head->push_content( $meta );
        }
    }

    # Add the total document length, which is different than the section length
    $head->push_content(
        HTML::Element->new('meta', name=> 'pagelen', content => $params->{page_length} )
    );


    my $body = HTML::Element->new('body');
    my $doc  = HTML::Element->new('html');

    $body->push_content( $section );
    $doc->push_content( $head, $body );

    # If we want to stip the base_path
    my $url = $uri->as_string;
    $url =~ s[$base_path/][];

    my $new_content = $doc->as_HTML(undef,"\t");
    output_content( $params->{server}, \$new_content,
                    $url, $params->{response} );

    $uri->fragment(undef);

    $params->{found}++;  # set flag;


    $doc->delete;
}

my %section_names;

sub map_path_to_sections {
    my $path = shift;

    %section_names = fetch_sections( $CHECKBOX_DATA )
        unless %section_names;


    my @sections;
    for ( keys %section_names ) {
        my $test = quotemeta( $_ );
        push @sections, $section_names{ $_ } if $path =~ /^$test/;
    }

    return @sections ? join(' ', @sections ) : undef;
}

        



use Storable;
sub fetch_sections {
    my $file = shift;

    my $items_array = retrieve( $file );
    die unless $items_array;

    my %sections;
    recurse_sections( \%sections, $items_array );
    return %sections;

}

sub recurse_sections {
    my ( $sections, $items_array ) = @_;

    for ( @$items_array ) {
        # grab the path and its associated section ID
        $sections->{ $_->{path} } = $_->{section};
        recurse_sections( $sections, $_->{subs} ) if $_->{subs};
    }
}



1;

