package DocSet::Source::POD;

use strict;
use warnings;

use DocSet::Util;
use DocSet::RunTime;

use vars qw(@ISA);
require DocSet::Doc;
@ISA = qw(DocSet::Doc);

use constant HEAD_MAX_LEVEL => 4;
use constant MAX_DESC_LENGTH => 500;

# META: we are presenting too early, or this code should be moved to
# POD2HTML specific module
require Pod::POM::View::HTML;
my $mode = 'Pod::POM::View::HTML';

sub retrieve_meta_data {
    my($self) = @_;

    $self->parse_pod;

    #print Pod::POM::View::HTML->print($pom);

    my $meta = {
        title => 'No Title',
        abstract => '',
    };

    my $pom = $self->{parsed_tree};
    my @sections = $pom->head1();

    
    if (@sections) {

        # extract the title from the NAME section and remove it from content
        if ($sections[0]->title =~ /NAME/) {
            # don't present on purpose ->present($mode); there should
            # be no markup in NAME a problem with
            # <TITLE><CODE>....</CODE><TITLE> and alike
            $meta->{title} = (shift @sections)->content();
            $meta->{title} =~ s/^\s*|\s*$//sg;
        }

        # stitle is the same in docs
        $meta->{stitle} = $meta->{title};

        # locate the DESCRIPTION section (should be in the first three
        # sections)
        for (0..2) {
            next unless defined $sections[$_]
                && $sections[$_]->title =~ /DESCRIPTION/i;

            my $abstract = $sections[$_]->content->present($mode);

# cannot do this now, as it might cut some markup in the middle: <i>1 2</i>
#            # we are interested only in the first paragraph, or if its
#            # too big first MAX_DESC_LENGTH chars.
#            my $index = index $abstract, " ", MAX_DESC_LENGTH;
#            # cut only if index didn't return '-1' which is when the the
#            # space wasn't found starting from location MAX_DESC_LENGTH
#            unless ($index == -1) {
#                $abstract = substr $abstract, 0, $index+1;
#                $abstract .= " ...&nbsp;<i>(continued)</i>";
#            }
#
#           # temp workaround, but can only split on paras
            $abstract =~ s|<p>(.*?)</p>.*|$1|s;

            $meta->{abstract} = $abstract;
            last;
        }
    }

    $meta->{link} = $self->{rel_dst_path};

    # put all the meta data under the same attribute
    $self->{meta} = $meta;

    # build the toc datastructure
    my @toc = ();
    my $level = 1;
    for my $node (@sections) {
        push @toc, $self->render_toc_level($node, $level);
    }
    $self->{toc} = \@toc;

}

sub render_toc_level {
    my($self, $node, $level) = @_;
    my $title = $node->title;
    my $link = "$title";  # must stringify to get the raw string
    $link =~ s/\W/_/g;    # META: put into a sub?
    $link = "#$link";     # prepand '#' for internal links

    my %toc_entry = (
        title => $title->present($mode), # run the formatting if any
        link  => $link,
        );

    my @sub = ();
    $level++;
    if ($level <= HEAD_MAX_LEVEL) {
        # if there are deeper than =head4 levels we don't go down (spec is 1-4)
        my $method = "head$level";
        for my $sub_node ($node->$method()) {
            push @sub, $self->render_toc_level($sub_node, $level);
        }
    }
    $toc_entry{subs} = \@sub if @sub;

    return \%toc_entry;
}



sub parse_pod {
    my($self) = @_;
    
    # already parsed
    return if exists $self->{parsed_tree} && $self->{parsed_tree};

    $self->podify_items() if get_opts('podify_items');

#    print ${ $self->{content} };

    use Pod::POM;
    my %options;
    my $parser = Pod::POM->new(\%options);
    my $pom = $parser->parse_text(${ $self->{content} })
        or die $parser->error();

    $self->{parsed_tree} = $pom;

    # examine any warnings raised
    if (my @warnings = $parser->warnings()) {
        print "\n", '-' x 40, "\n";
        print "File: $self->{src_path}\n";
        warn "$_\n" for @warnings;
    }
}

sub src_filter {
    my ($self) = @_;

    $self->extract_pod;

    $self->podify_items if get_opts('podify_items');
}

sub extract_pod {
    my($self) = @_;

    my @pod = ();
    my $in_pod = 0;
    for (split /\n\n/, ${ $self->{content} }) {
        $in_pod ||= /^=/s;
        next unless $in_pod;
        $in_pod = 0 if /^=cut/;
        push @pod, $_;
    }

    # handle empty files
    unless (@pod) {
        push @pod, "=head1 NAME", "=head1 Not documented", "=cut";
    }

    my $content = join "\n\n", @pod;
    $self->{content} = \$content;
}

sub podify_items {
    my($self) = @_;
  
    # tmp storage
    my @paras = ();
    my $items = 0;
    my $second = 0;

    # we want the source in paragraphs
    my @content = split /\n\n/, ${ $self->{content} };

    foreach (@content) {
        # is it an item?
        if (/^(\*|\d+)\s+((\*|\d+)\s+)?/) {
            $items++;
            if ($2) {
                $second++;
                s/^(\*|\d+)\s+//; # strip the first level shortcut
                s/^(\*|\d+)\s+/=item $1\n\n/; # do the second
                s/^/=over 4\n\n/ if $second == 1; # start 2nd level
            } else {
                # first time insert the =over pod tag
                s/^(\*|\d+)\s+/=item $1\n\n/; # start 1st level
                s/^/=over 4\n\n/ if $items == 1;
                s/^/=back\n\n/   if $second; # complete 2nd level
                $second = 0; # end 2nd level section
            }
            push @paras, split /\n\n/, $_;
        } else {
          # complete the =over =item =back tag
            $second=0, push @paras, "=back" if $second; # if 2nd level is not closed
            push @paras, "=back" if $items;
            push @paras, $_;
          # not a tag item
            $items = 0;
        }
    }

    my $content = join "\n\n", @paras;
    $self->{content} = \$content;

}

1;
__END__

=head1 NAME

C<DocSet::Source::POD> - A class for parsing input document in the POD format

=head1 SYNOPSIS



=head1 DESCRIPTION

=head2 METHODS

=over 

=item retrieve_meta_data()

=item parse_pod()

=item podify_items()

  podify_items();

Podify text to represent items in pod, e.g:

  1 Some text from item Item1
  
  2 Some text from item Item2

becomes:

  =over 4
 
  =item 1
 
  Some text from item Item1

  =item 2
 
  Some text from item Item2

  =back

podify_items() accepts 'C<*>' and digits as bullets

podify_items() receives a ref to array of paragraphs as a parameter
and modifies it. Nothing returned.

Moreover, you can use a second level of indentation. So you can have

  * title

  * * item

  * * item

or 

  * title

  * 1 item

  * 2 item

where the second mark is which tells whether to use a ball bullet or a
numbered item.


=back

=head1 AUTHORS

Stas Bekman E<lt>stas (at) stason.orgE<gt>

=cut
