package DocSet::Doc::Common;

use File::Spec::Functions;
use DocSet::Util;
use DocSet::RunTime;

# See  HTML2HTMLPS.pm or POD2HTMLPS.pm
sub postprocess_ps_pdf {
    my $self = shift;

    # convert to ps
    my $html2ps_exec = DocSet::RunTime::can_create_ps();
    my $html2ps_conf = $self->{docset}->get_file('html2ps_conf');
    my $dst_path     = $self->{dst_path};

    (my $dst_base  = $dst_path) =~ s/\.html//;

    my $dst_root = $self->{dst_root};
    my $command = "$html2ps_exec -f $html2ps_conf -o ${dst_base}.ps ${dst_base}.html";
    note "% $command";
    system $command;

    # convert to pdf
    $command = "ps2pdf ${dst_base}.ps ${dst_base}.pdf";
    note "% $command";
    system $command;

    # META: can delete the .ps now

}



# search for a pdf version in the parallel tree and copy/gzip it to
# the same dir as the html version (we link to it from the html)
sub fetch_pdf_doc_ver {
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
sub fetch_src_doc_ver {
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
}


# These are POD::POM functions
sub pod_pom_html_view_seq_link {
    my ($self, $link) = @_;
#dumper $link;
#print "$link\n";
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
        $url = "$page.html";
        $url =~ s|::|/|g;
    }

    # append the #section if exists
    $url .= "#$section" if defined $section and length $section;

    return make_href($url, $linktext);
}

sub make_href {
    my($url, $title) = @_;
#print "$url, $title\n";
#    $title = $url unless defined $title;
#    return qq{<a href="$url">$title</a>};
}

sub pod_pom_html_anchor {
    my($self, $title) = @_;
    my $anchor = "$title";
    $anchor =~ s/^\s*|\s*$//g; # strip leading and closing spaces
    $anchor =~ s/\W/_/g;
    my $link = $title->present($self);
    return qq{<a name="$anchor">$link</a>};
}

# we want the pre sections look different from normal text. So we use
# the vertical bar on the left
sub pod_pom_html_view_verbatim {
    my ($self, $text) = @_;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
    }

    return <<PRE_SECTION;
<table>
  <tr>

    <td bgcolor="#cccccc" width="1">
      &nbsp;
    </td>

    <td>
      <pre>$text</pre>
    </td>

  </tr>
</table>
PRE_SECTION

}


1;
__END__
