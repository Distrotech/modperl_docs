package DocSet::Doc::POD2HTML;

use strict;
use warnings;

use File::Spec::Functions;

use DocSet::Util;

require Pod::POM;
#require Pod::POM::View::HTML;
#my $view_mode = 'Pod::POM::View::HTML';
my $view_mode = 'DocSet::Doc::POD2HTML::View::HTML';

use DocSet::Doc::Common ();
*fetch_pdf_doc_ver = \&DocSet::Doc::Common::fetch_pdf_doc_ver;
*fetch_src_doc_ver = \&DocSet::Doc::Common::fetch_src_doc_ver;

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
                pdf_doc  => $self->fetch_pdf_doc_ver,
                src_doc  => $self->fetch_src_doc_ver,
               };

    my $tmpl_file = 'page';
    my $mode = $self->{tmpl_mode};
    my $tmpl_root = $self->{tmpl_root};
    $self->{output} = proc_tmpl($tmpl_root, $tmpl_file, $mode, {doc => $vars} );

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

*anchor        = \&DocSet::Doc::Common::pod_pom_html_anchor;
*view_seq_link = \&DocSet::Doc::Common::pod_pom_html_view_seq_link;
*view_verbatim = \&DocSet::Doc::Common::pod_pom_html_view_verbatim;

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

