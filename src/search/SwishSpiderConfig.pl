# this is the modified default spider config file that comes with swish-e.
#
# a few custom callbacks are located after the @servers definition section.

@servers = (
    {
        base_url        => 'http://mardy:40994/dst_html/index.html',

        # Debugging -- see perldoc spider.pl

        #base_url        => 'http://mardy.hank.org:40994/dst_html/docs/guide/index.html',
        #max_depth => 1,
        #debug => DEBUG_HEADERS,
        #debug => DEBUG_URL|DEBUG_SKIPPED|DEBUG_INFO,
        #debug => DEBUG_LINKS,

        keep_alive      => 1,         # enable keep alives requests
        email           => 'swish@domain.invalid',

        use_md5         => 1,    # catch duplicates ( / and /index.html )

        delay_min       => .0001,

        # Ignore images files
        test_url        => sub { $_[0]->path !~ /\.(?:gif|jpe?g|.png)$/i },

        # Only index text/html
        test_response   => sub { return $_[2]->content_type =~ m[text/html] },

        # split content - comment out to disable splitting
        filter_content  => \&split_page,

        # optionally validate external links
        validate_links => 1,
    },

);

use HTML::TreeBuilder;
use HTML::Element;

sub split_page {

    my %params;
    @params{ qw/ uri server response content / } = @_;
    $params{found} = 0;


    my $tree = HTML::TreeBuilder->new;
    $tree->parse( ${$params{content}} );  # Why not allow a scalar ref?
    $tree->eof;

    my $head = $tree->look_down( '_tag', 'head' );

    for my $section ( $tree->look_down( '_tag', 'div', 'class', 'index_section' ) ) {
        create_page( $head->clone, $section->clone, \%params )
    }

    $tree->delete;

    return !$params{found};  # tell spider.pl to not index the page
}

sub create_page {
    my ( $head, $section, $params ) = @_;

    my $uri = $params->{uri};

    my $section_name = 'Unknown_Section';
    my $name = $section->look_down( '_tag', 'a',
                                    sub { defined($_[0]->attr('name')) } );

    if ( $name ) {
        $section_name = $name->attr('name');
        $uri->fragment( $section_name );
    }

    my $text_title = $section_name;
    $text_title =~ tr/_/ /s;

    my $title = $head->look_down('_tag', 'title');

    if ( $title ) {
        $title->push_content(": $text_title");
    } else {
        my $title = HTML::Element->new('title');
        $title->push_content(": $text_title");
        $head->push_content( $title );
    }

    my $body = HTML::Element->new('body');
    my $doc  = HTML::Element->new('html');

    $body->push_content( $section );
    $doc->push_content( $head, $body );

    my $new_content = $doc->as_HTML(undef,"\t");
    output_content( $params->{server}, \$new_content,
                    $uri, $params->{response} );

    $uri->fragment(undef);

    $params->{found}++;  # set flag;

    $doc->delete;
}


1;

