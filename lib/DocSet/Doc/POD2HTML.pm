package DocSet::Doc::POD2HTML;

use strict;
use warnings;

use File::Spec::Functions;

use DocSet::Util;
require Pod::POM;
#require Pod::POM::View::HTML;
#my $view_mode = 'Pod::POM::View::HTML';
my $view_mode = 'DocSet::Doc::POD2HTML::View::HTML';

use vars qw(@ISA);
require DocSet::Source::POD;
@ISA = qw(DocSet::Source::POD);

my %split_by = map {"head".$_ => 1} 1..4;

sub convert {
    my($self) = @_;

    my $pom = $self->{parsed_tree};

    my @sections = $pom->content();
    shift @sections; # skip the title

#    my @body = ();
#    foreach my $node (@sections) {
##	my $type = $node->type();
##        print "$type\n";
#	push @body, $node->present($view_mode);
#    }

    
    #dumper $sections[$#sections];

    my @body = slice_by_head(@sections);

    my $vars = {
                meta => $self->{meta},
                toc  => $self->{toc},
                body => \@body,
                dir  => $self->{dir},
                nav  => $self->{nav},
                last_modified => $self->{timestamp},
                pdf_doc  => $self->pdf_doc,
                src_doc  => $self->src_doc,
               };

    my $tmpl_file = 'page';
    my $mode = $self->{tmpl_mode};
    my $tmpl_root = $self->{tmpl_root};
    $self->{output} = proc_tmpl($tmpl_root, $tmpl_file, $mode, {doc => $vars} );

}

# search for a pdf version in the parallel tree and copy/gzip it to
# the same dir as the html version (we link to it from the html)
sub pdf_doc {
    my $self = shift;

    my $dst_path = $self->{dst_path};
    $dst_path =~ s/html$/pdf/;

    my $pdf_path = $dst_path;

    my $docset = $self->{docset};
    my $ps_root = $docset->get_dir('dst_ps');
    my $html_root = $docset->get_dir('dst_html');

    $pdf_path =~ s/^$html_root/$ps_root/;

#print "TRYING $dst_path $pdf_path \n";

    my %pdf = ();
    if (-e $pdf_path) {
        copy_file($pdf_path, $dst_path);
        gzip_file($dst_path);
        my $gzip_path = "$dst_path.gz";
        %pdf = (
            size => format_bytes(-s $gzip_path),
            link => filename($gzip_path),
        );
    }
#dumper \%pdf;

    return \%pdf;

}

# search for the source version in the source tree and copy/gzip it to
# the same dir as the html version (we link to it from the html)
sub src_doc {
    my $self = shift;
    #$self->src_uri

    my $dst_path = catfile $self->{dst_root}, $self->{src_uri};
    my $src_path = catfile $self->{src_root}, $self->{src_uri};

#print "TRYING $dst_path $src_path \n";

    my %src = ();
    if (-e $src_path) {
        # it's ok if the source file has the same name as the dest,
        # because the final dest file wasn't created yet.
        copy_file($src_path, $dst_path);
        gzip_file($dst_path);
        my $gzip_path = "$dst_path.gz";
        %src = (
            size => format_bytes(-s $gzip_path),
            link => filename($gzip_path),
        );
    }
#dumper \%src;

    return \%src;
die;
}


sub slice_by_head {
    my @sections = @_;
    my @body = ();
    for my $node (@sections) {
        my @next = ();
        # assumption, after the first 'headX' section, there can only
        # be other 'headX' sections
        my $count = scalar $node->content;
        my $id = -1;
        for ($node->content) {
            $id++;
            next unless exists $split_by{ $_->type };
            @next = splice @{$node->content}, $id;
            last;
        }
        push @body, $node->present($view_mode), slice_by_head(@next);
    }
    return @body;
}


1;


package DocSet::Doc::POD2HTML::View::HTML;

use vars qw(@ISA);
require Pod::POM::View::HTML;
@ISA = qw( Pod::POM::View::HTML);

sub view_head1 {
    my ($self, $head1) = @_;
    return "<h1>" . $self->anchor($head1->title) . "</h1>\n\n" .
        $head1->content->present($self);
}

sub view_head2 {
    my ($self, $head2) = @_;
    return "<h2>" . $self->anchor($head2->title) . "</h2>\n\n" .
        $head2->content->present($self);
}

sub view_head3 {
    my ($self, $head3) = @_;
    return "<h3>" . $self->anchor($head3->title) . "</h3>\n\n" .
        $head3->content->present($self);
}

sub view_head4 {
    my ($self, $head4) = @_;
    return "<h4>" . $self->anchor($head4->title) . "</h4>\n\n" .
        $head4->content->present($self);
}

sub anchor {
    my($self, $title) = @_;
    my $anchor = "$title";
    $anchor =~ s/\W/_/g;
    my $link = $title->present($self);
    return qq{<a name="$anchor">$link</a>};
}


sub view_seq_link {
    my ($self, $link) = @_;

    # full-blown URL's are emitted as-is
    if ($link =~ m{^\w+://}s ){
        return make_href($link);
    }

    $link =~ s/\n/ /g;   # undo word-wrapped tags

    my $orig_link = $link;
    my $linktext;
    # strip the sub-title and the following '|' char
    if ( $link =~ s/^ ([^|]+) \| //x ) {
        $linktext = $1;
    }
    
    # make sure sections start with a /
    $link =~ s|^"|/"|;

    my $page;
    my $section;
    if ($link =~ m|^ (.*?) / "? (.*?) "? $|x) { # [name]/"section"
        ($page, $section) = ($1, $2);
    }
    elsif ($link =~ /\s/) {  # this must be a section with missing quotes
        ($page, $section) = ('', $link);
    }
    else {
        ($page, $section) = ($link, '');
    }

    # warning; show some text.
    $linktext = $orig_link unless defined $linktext;

    my $url = '';
    if (defined $page && length $page) {
        $url = $page;
        $url =~ s|::|/|g;
    }

    # append the #section if exists
    $url .= "#$section" if defined $section and length $section;

    return make_href($url, $linktext);
}

sub make_href {
    my($url, $title) = @_;
    $title = $url unless defined $title;
    return qq{<a href="$url">$title</a>};
}


1;



__END__

=head1 NAME

C<DocSet::Doc::POD2HTML> - POD source to HTML target converter

=head1 SYNOPSIS



=head1 DESCRIPTION

Implements an C<DocSet::Doc> sub-class which converts a source
document in POD, into an output document in HTML.

=head1 METHODS

For the rest of the super class methods see C<DocSet::Doc>.

=over

=item * convert

=back

=head1 AUTHORS

Stas Bekman E<lt>stas (at) stason.orgE<gt>

=cut

