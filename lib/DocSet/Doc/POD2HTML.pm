package DocSet::Doc::POD2HTML;

use strict;
use warnings;

use DocSet::Util;
require Pod::POM;
#require Pod::POM::View::HTML;
#my $view_mode = 'Pod::POM::View::HTML';
my $view_mode = 'DocSet::Doc::POD2HTML::View::HTML';

use vars qw(@ISA);
require DocSet::Source::POD;
@ISA = qw(DocSet::Source::POD);

sub convert {
    my($self) = @_;

    my $pom = $self->{parsed_tree};
    
#    my @sections = $pom->head1();
#    shift @sections; # skip the title

    my @sections = $pom->content();
    shift @sections; # skip the title

    my @body = ();
    foreach my $node (@sections) {
#	my $type = $node->type();
#        print "$type\n";
	push @body, $node->present($view_mode);
    }

#    for my $head1 (@sections) {
#        push @body, $head1->title->present($view_mode);
#        push @body, $head1->content->present($view_mode);
#        for my $head2 ($head1->head2) {
#            push @body, $head2->present($view_mode);
#            for my $head3 ($head2->head3) {
#                push @body, $head3->present($view_mode);
#                for my $head4 ($head3->head4) {
#                    push @body, $head4->present($view_mode);
#                }
#            }
#        }
#    }

    my $vars = {
                meta => $self->{meta},
                toc  => $self->{toc},
                body => \@body,
                dir  => $self->{dir},
                nav  => $self->{nav},
                last_modified => $self->{timestamp},
               };

    my $tmpl_file = 'page';
    my $mode = $self->{tmpl_mode};
    my $tmpl_root = $self->{tmpl_root};
    $self->{output} = proc_tmpl($tmpl_root, $tmpl_file, $mode, {doc => $vars} );

}

1;


package DocSet::Doc::POD2HTML::View::HTML;

use vars qw(@ISA);
require Pod::POM::View::HTML;
@ISA = qw( Pod::POM::View::HTML);

sub view_head1 {
    my ($self, $node) = @_;
    return $self->anchor($node->title) . $self->SUPER::view_head1($node);
}

sub view_head2 {
    my ($self, $node) = @_;
    return $self->anchor($node->title) . $self->SUPER::view_head2($node);
}

sub view_head3 {
    my ($self, $node) = @_;
    return $self->anchor($node->title) . $self->SUPER::view_head3($node);
}

sub view_head4 {
    my ($self, $node) = @_;
    return $self->anchor($node->title) . $self->SUPER::view_head4($node);
}

sub anchor {
    my($self, $title) = @_;
    my $anchor = "$title";
    $anchor =~ s/\W/_/g;
    return qq{<a name="$anchor"></a>\n};
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

